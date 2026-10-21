import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/technical_media.dart';

class TechnicalMediaPanel extends ConsumerStatefulWidget {
  const TechnicalMediaPanel({super.key, required this.item});
  final Item item;
  @override
  ConsumerState<TechnicalMediaPanel> createState() => _TechnicalMediaState();
}

class _TechnicalMediaState extends ConsumerState<TechnicalMediaPanel> {
  TechnicalMediaAnalyzer get _analysis =>
      TechnicalMediaAnalyzer(ref.read(appDatabaseProvider));
  late Future<Map<String, dynamic>?> _data = _analysis.read(widget.item);
  bool _busy = false;
  String? _error;
  @override
  void didUpdateWidget(covariant TechnicalMediaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) _data = _analysis.read(widget.item);
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _analysis.analyze(widget.item);
      if (mounted) setState(() => _data = _analysis.read(widget.item));
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : 'File analysis could not finish. Try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _data,
    builder: (context, snapshot) {
      final data = snapshot.data;
      final streams = data?['streams'] as List? ?? [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Technical media',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_error != null) Text(_error!),
          if (snapshot.hasError)
            const Text(
              'Saved technical data could not be read. Analyze the file again.',
            ),
          if (data == null || data['analysisState'] == 'indexed')
            const Text('This file has not been analyzed yet.'),
          if (data?['analysisState'] == 'failed')
            const Text('The file could not be analyzed. You can retry.'),
          if (data?['analysisState'] == 'unsupported')
            const Text(
              'The local analyzer did not recognize streams in this file.',
            ),
          if (data?['durationSeconds'] case final num duration)
            Text(
              '${(duration / 60).toStringAsFixed(1)} minutes · ${data?['container'] ?? 'unknown'} file',
            ),
          for (final stream in streams)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                [
                  '${stream['kind']} ${stream['id']}',
                  if (stream['codec'] != null) '${stream['codec']}',
                  if (stream['width'] != null && stream['height'] != null)
                    '${stream['width']} × ${stream['height']}',
                  if (stream['frameRate'] is num)
                    '${(stream['frameRate'] as num).toStringAsFixed(2)} fps',
                  if (stream['channels'] != null)
                    '${stream['channels']} channels',
                  if (stream['sampleRate'] != null)
                    '${stream['sampleRate']} Hz',
                  if (stream['bitrate'] is num)
                    '${((stream['bitrate'] as num) / 1000).round()} kb/s',
                  if (stream['language'] != null) '${stream['language']}',
                ].join(' · '),
              ),
            ),
          if (TechnicalMediaAnalyzer.supports(widget.item))
            OutlinedButton.icon(
              onPressed: _busy || widget.item.unavailable ? null : _run,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics_outlined),
              label: Text(_busy ? 'Analyzing file…' : 'Analyze file'),
            ),
          if (!TechnicalMediaAnalyzer.supports(widget.item) && streams.isEmpty)
            const Text(
              'Technical analysis runs on the Mac that hosts the file.',
            ),
        ],
      );
    },
  );
}
