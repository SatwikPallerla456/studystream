import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/reader/reader_image_analysis.dart';
import '../../domain/reader/reader_jobs.dart';

Future<String?> showReaderTextAnalysis({
  required BuildContext context,
  required ReaderJobScheduler jobs,
  required String pageKey,
  required Future<Uint8List> Function(ReaderCancellation) raster,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _ReaderTextAnalysis(jobs: jobs, pageKey: pageKey, raster: raster),
);

class _ReaderTextAnalysis extends StatefulWidget {
  const _ReaderTextAnalysis({
    required this.jobs,
    required this.pageKey,
    required this.raster,
  });
  final ReaderJobScheduler jobs;
  final String pageKey;
  final Future<Uint8List> Function(ReaderCancellation) raster;
  @override
  State<_ReaderTextAnalysis> createState() => _ReaderTextAnalysisState();
}

class _ReaderTextAnalysisState extends State<_ReaderTextAnalysis> {
  ReaderLease<List<RecognizedReaderLine>>? _lease;
  String? _text, _error;
  String _selection = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _lease = widget.jobs.request<List<RecognizedReaderLine>>(
        key: '${widget.pageKey}:ocr-v1-white',
        priority: ReaderPriority.analysis,
        estimatedBytes: 64 * 1024 * 1024,
        run: (token) async {
          final png = await widget.raster(token);
          token.check();
          return ReaderImageAnalysis.recognize(png, token);
        },
      );
      final lines = await _lease!.future;
      if (!mounted) return;
      final text = lines.map((line) => line.text).join('\n');
      setState(() {
        _text = text;
        _selection = text.length <= 4000 ? text : '';
      });
    } catch (error) {
      if (mounted && error is! ReaderCancelled)
        setState(
          () => _error = error is PlatformException
              ? error.message ?? 'Text recognition is unavailable. Try again.'
              : 'Text could not be recognized. Try again on a clearer page.',
        );
    }
  }

  @override
  void dispose() {
    _lease?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Recognize text on this page'),
    content: SizedBox(
      width: 600,
      height: MediaQuery.sizeOf(context).height * .55,
      child: _error != null
          ? Text(_error!)
          : _text == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recognized on this device. Check for errors before using the text.',
                ),
                const SizedBox(height: 12),
                if (_text!.length > 4000)
                  const Text('Select up to 4,000 characters to use in a note.'),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _text!.isEmpty
                          ? 'No text was found on this page.'
                          : _text!,
                      onSelectionChanged: (range, _) {
                        if (_text!.isEmpty ||
                            !range.isValid ||
                            range.isCollapsed ||
                            range.end > _text!.length)
                          return;
                        final value = range.textInside(_text!);
                        setState(
                          () => _selection = value.length <= 4000 ? value : '',
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      if (_text?.isNotEmpty == true)
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: _text!)),
          icon: const Icon(Icons.copy),
          label: const Text('Copy all'),
        ),
      FilledButton(
        onPressed: _selection.isEmpty
            ? null
            : () => Navigator.pop(context, _selection),
        child: const Text('Use in a page note'),
      ),
    ],
  );
}
