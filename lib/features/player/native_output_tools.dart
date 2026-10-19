import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/playback/playback_engine.dart';
import '../../shared/widgets/study_ui.dart';

class NativeOutputTools extends StatefulWidget {
  const NativeOutputTools({super.key, required this.engine});
  final NativeVlcEngine engine;
  @override
  State<NativeOutputTools> createState() => _NativeOutputToolsState();
}

class _NativeOutputToolsState extends State<NativeOutputTools> {
  String _format = 'mp4';
  final _host = TextEditingController(text: '127.0.0.1');
  final _port = TextEditingController(text: '8090');
  bool _audio = true, _video = true, _subtitles = false, _busy = false;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'The output could not start. Check the destination, playback state and available codecs.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = (widget.engine.diagnostics['jobs'] as List? ?? []).cast<Map>();
    final devices = (widget.engine.diagnostics['castDevices'] as List? ?? [])
        .cast<Map>();
    return StudyModalFrame(
      title: 'Outputs & windows',
      icon: Icons.cast,
      primaryAction: FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .58,
        child: ListView(
          children: [
            if (_error != null) Text(_error!),
            for (final error
                in (widget.engine.diagnostics['shortcutErrors'] as List? ?? []))
              Text(error as String),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(widget.engine.toggleMini),
                  icon: const Icon(Icons.picture_in_picture_alt),
                  label: const Text('Mini-player'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(widget.engine.toggleFullscreen),
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Fullscreen'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await widget.engine.snapshot();
                        }),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Snapshot'),
                ),
              ],
            ),
            const Divider(),
            DropdownButtonFormField<String>(
              initialValue: _format,
              decoration: const InputDecoration(labelText: 'Output format'),
              items: [
                for (final entry in const {
                  'mp4': 'MP4 · H.264/AAC',
                  'webm': 'WebM · VP8/Vorbis',
                  'mp3': 'MP3 audio',
                  'flac': 'FLAC audio',
                  'ts': 'Original streams · MPEG-TS',
                }.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _format = value!),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await widget.engine.startOutput(
                            mode: 'convert',
                            format: _format,
                          );
                        }),
                  icon: const Icon(Icons.transform),
                  label: const Text('Convert / save'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await widget.engine.startOutput(
                            mode: 'record',
                            format: _format,
                          );
                        }),
                  icon: const Icon(Icons.fiber_manual_record),
                  label: const Text('Record from current position'),
                ),
              ],
            ),
            const Text(
              'Start playback before recording. Pause also pauses the recording; seeking or closing the player finalizes it. Keep the player open while outputs run.',
            ),
            const Divider(),
            const Text(
              'HTTP stream output',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Bind address (127.0.0.1 keeps it on this Mac)',
              ),
            ),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port (1024–65535)'),
            ),
            Wrap(
              children: [
                FilterChip(
                  label: const Text('Audio'),
                  selected: _audio,
                  onSelected: (v) => setState(() => _audio = v),
                ),
                FilterChip(
                  label: const Text('Video'),
                  selected: _video,
                  onSelected: (v) => setState(() => _video = v),
                ),
                FilterChip(
                  label: const Text('Subtitle overlay'),
                  selected: _subtitles,
                  onSelected: (v) => setState(() => _subtitles = v),
                ),
              ],
            ),
            const Text(
              'This MPEG-TS output is unencrypted and has no pairing authentication. A LAN bind address makes it available to other devices on that network.',
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final port = int.tryParse(_port.text);
                      if (port == null ||
                          port < 1024 ||
                          port > 65535 ||
                          _host.text.trim().isEmpty ||
                          !(_audio || _video)) {
                        throw const FormatException();
                      }
                      await widget.engine.startOutput(
                        mode: 'stream',
                        host: _host.text.trim(),
                        port: port,
                        audio: _audio,
                        video: _video,
                        subtitles: _subtitles,
                      );
                    }),
              child: const Text('Start stream output'),
            ),
            for (final job in jobs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${job['title']} · ${job['state']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (job['finished'] != true)
                      LinearProgressIndicator(
                        value: (job['progress'] as num?)?.toDouble().clamp(
                          0,
                          1,
                        ),
                      ),
                    if ((job['path'] as String? ?? '').isNotEmpty)
                      SelectableText(job['path'] as String),
                    if ((job['error'] as String? ?? '').isNotEmpty)
                      Text(job['error'] as String),
                  ],
                ),
                trailing: job['finished'] == true
                    ? null
                    : IconButton(
                        tooltip: 'Finish output',
                        icon: const Icon(Icons.stop),
                        onPressed: () => _run(
                          () => widget.engine.finishOutput(job['id'] as String),
                        ),
                      ),
              ),
            const Divider(),
            const Text('Cast', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              widget.engine.diagnostics['castStatus'] as String? ??
                  'Not scanning',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _run(widget.engine.scanCast),
                  child: const Text('Find receivers'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(widget.engine.stopCastScan),
                  child: const Text('Stop discovery'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => widget.engine.selectCast(null)),
                  child: const Text('Play on this Mac'),
                ),
              ],
            ),
            for (final device in devices)
              ListTile(
                title: Text(device['name'] as String),
                leading: const Icon(Icons.cast),
                onTap: () => _run(
                  () => widget.engine.selectCast(device['id'] as String),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
