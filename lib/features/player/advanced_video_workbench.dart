import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:uuid/uuid.dart';
import '../../data/db/app_database.dart';
import '../../data/playback/playback_engine.dart';
import '../../data/sync/lan_sync_client.dart';
import '../../domain/services/video_playback_workspace.dart';
import 'desktop_playback_windows.dart';
import 'video_comparison_screen.dart';
import 'video_session_tools.dart';
import 'video_subtitles.dart';

String videoTime(int ms) =>
    '${(ms ~/ 3600000).toString().padLeft(2, '0')}:${(ms ~/ 60000 % 60).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';

class AdvancedVideoWorkbench extends StatefulWidget {
  const AdvancedVideoWorkbench({
    super.key,
    required this.player,
    required this.database,
    required this.client,
    required this.item,
    required this.tools,
    required this.onSeek,
    required this.onCapture,
    required this.onPip,
    this.onPositionIntent,
  });
  final PlaybackEngine player;
  final AppDatabase database;
  final LanSyncClient client;
  final Item item;
  final VideoSessionTools tools;
  final Future<void> Function(Duration) onSeek;
  final Future<void> Function() onCapture;
  final VoidCallback onPip;
  final VoidCallback? onPositionIntent;
  @override
  State<AdvancedVideoWorkbench> createState() => _AdvancedVideoState();
}

class _AdvancedVideoState extends State<AdvancedVideoWorkbench> {
  late final _workspace = VideoPlaybackWorkspace(
    widget.database,
    widget.item.id,
  );
  List<VideoPlaybackProfile> _profiles = [];
  List<VideoTimelineEntry> _timeline = [];
  VideoPlaybackProfile _active = const VideoPlaybackProfile(
    id: 'current',
    name: 'Current settings',
  );
  String? _error;
  bool _busy = false;
  Timer? _timer;
  DateTime? _bufferingSince;
  DateTime _advanced = DateTime.now();
  Duration _lastPosition = Duration.zero;
  VideoSubtitleTranslator? _translator;
  String? _translationProgress;
  NativeVlcEngine? get _native => widget.player is NativeVlcEngine
      ? widget.player as NativeVlcEngine
      : null;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final state = widget.player.state;
      if (state.buffering) {
        _bufferingSince ??= DateTime.now();
      } else {
        _bufferingSince = null;
      }
      if (state.position != _lastPosition) {
        _advanced = DateTime.now();
        _lastPosition = state.position;
      }
      setState(() {});
    });
  }

  Future<void> _load() async {
    try {
      final profiles = await _workspace.profiles(),
          timeline = await _workspace.timeline();
      final active = await _workspace.activeProfile();
      if (mounted)
        setState(() {
          _profiles = profiles;
          _timeline = timeline;
          _active = active ?? _active;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Saved video tools could not be loaded.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is FormatException
              ? e.message.toString()
              : 'This action could not finish. Check the source, destination and platform support.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _translator?.close();
    super.dispose();
  }

  Widget _button(
    String text,
    Future<void> Function() action, {
    IconData icon = Icons.chevron_right,
  }) => OutlinedButton.icon(
    onPressed: _busy ? null : () => _run(action),
    icon: Icon(icon),
    label: Text(text),
  );
  Widget _list(List<Widget> children) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_busy) const LinearProgressIndicator(),
      ...children,
    ],
  );
  Future<String?> _text(
    String title, {
    String initial = '',
    int lines = 1,
    int max = 160,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: lines,
            maxLength: max,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _select(
    VideoPlaybackProfile profile, {
    bool save = false,
  }) async {
    if (save) await _workspace.saveProfile(profile);
    if (mounted) Navigator.pop(context, profile);
  }

  Future<void> _customProfile({
    bool? dialogue,
    bool? normalize,
    int? cache,
    bool? software,
  }) => _select(
    _active.copyWith(
      id: 'custom-${sha256.convert(utf8.encode(widget.item.id)).toString().substring(0, 16)}',
      name: 'Custom playback',
      dialogue: dialogue,
      normalize: normalize,
      networkCache: cache,
      softwareDecoder: software,
      speed: widget.player.state.rate,
      subtitleSize: widget.tools.subtitles.size,
      subtitleColor: widget.tools.subtitles.color,
    ),
    save: true,
  );
  Future<void> _createProfile() async {
    final name = TextEditingController(text: _active.name);
    final speed = TextEditingController(text: '${widget.player.state.rate}');
    final size = TextEditingController(text: '${widget.tools.subtitles.size}');
    var dialogue = _active.dialogue, normalize = _active.normalize;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Named playback profile'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Profile name',
                    ),
                  ),
                  TextField(
                    controller: speed,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Playback speed (0.25–3)',
                    ),
                  ),
                  TextField(
                    controller: size,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Subtitle size (12–60)',
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Enhance dialogue'),
                    value: dialogue,
                    onChanged: (v) => update(() => dialogue = v),
                  ),
                  SwitchListTile(
                    title: const Text('Normalize loudness'),
                    value: normalize,
                    onChanged: (v) => update(() => normalize = v),
                  ),
                  const Text(
                    'The active output route, decoder/cache choices and subtitle colour are retained.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save and apply'),
            ),
          ],
        ),
      ),
    );
    final profile = _active.copyWith(
      id: const Uuid().v4(),
      name: name.text.trim(),
      speed: double.tryParse(speed.text) ?? double.nan,
      subtitleSize: double.tryParse(size.text) ?? double.nan,
      subtitleColor: widget.tools.subtitles.color,
      dialogue: dialogue,
      normalize: normalize,
    );
    name.dispose();
    speed.dispose();
    size.dispose();
    if (save == true)
      await _select(
        VideoPlaybackProfile.fromJson(profile.toJson()),
        save: true,
      );
  }

  Widget _profilePage() => _list([
    const Text(
      'Apply a profile to this title. The player restarts at the same position and keeps its playing/paused state. Audio-filter support depends on the installed libVLC modules.',
    ),
    for (final profile in _profiles)
      ListTile(
        title: Text(profile.name),
        subtitle: Text(
          '${profile.speed}× · ${profile.dialogue ? 'speech EQ' : 'neutral EQ'} · ${profile.normalize ? 'normalize loudness' : 'original loudness'}',
        ),
        leading: Icon(
          profile.id == _active.id ? Icons.check_circle : Icons.tune,
        ),
        trailing: Wrap(
          children: [
            if (!VideoPlaybackProfile.builtins.any((p) => p.id == profile.id))
              IconButton(
                tooltip: 'Delete profile',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await _workspace.deleteProfile(profile.id);
                        await _load();
                      }),
              ),
          ],
        ),
        onTap: _busy ? null : () => _run(() => _select(profile)),
      ),
    _button(
      'Create named playback profile',
      _createProfile,
      icon: Icons.save_outlined,
    ),
  ]);
  Future<void> _addMarker({bool clip = false}) async {
    final tools = widget.tools;
    if (clip &&
        (tools.loopA == null ||
            tools.loopB == null ||
            tools.loopB! <= tools.loopA!))
      throw const FormatException('Mark A and B before saving a clip.');
    final title = await _text(clip ? 'Clip title' : 'Chapter marker title');
    if (title == null) return;
    final note = await _text('Contextual annotation', lines: 4, max: 8000);
    if (note == null) return;
    await _workspace.add(
      title: title,
      start: clip ? tools.loopA! : widget.player.state.position.inMilliseconds,
      end: clip ? tools.loopB : null,
      note: note,
    );
    await _load();
  }

  Future<void> _export(VideoTimelineEntry entry) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export annotated clip reference',
      fileName: 'Tangerine-clip.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return;
    final json = {
      'schema': 'tangerine.annotated-clip.v1',
      'itemId': widget.item.id,
      'libraryId': widget.item.libraryId,
      'title': widget.item.userTitle ?? widget.item.title,
      'fingerprint': widget.item.fingerprint,
      'range': entry.toJson(),
    };
    await File(
      path,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  Widget _timelinePage() {
    final tools = widget.tools,
        position = widget.player.state.position.inMilliseconds;
    final chapters = (_native?.diagnostics['chapters'] as num?)?.toInt() ?? 0;
    return _list([
      Text('Current position · ${videoTime(position)}'),
      Text(
        'A: ${tools.loopA == null ? 'unset' : videoTime(tools.loopA!)}    B: ${tools.loopB == null ? 'unset' : videoTime(tools.loopB!)}',
      ),
      Wrap(
        spacing: 8,
        children: [
          _button(
            'Mark A',
            () => tools.setLoop(position, null, enabled: false),
          ),
          _button(
            'Mark B',
            () => tools.setLoop(tools.loopA, position, enabled: false),
          ),
          _button(
            tools.loopEnabled ? 'Disable A–B loop' : 'Enable A–B loop',
            () => tools.setLoop(
              tools.loopA,
              tools.loopB,
              enabled: !tools.loopEnabled,
            ),
          ),
          _button(
            'Add named chapter marker',
            () => _addMarker(),
            icon: Icons.bookmark_add_outlined,
          ),
          _button(
            'Save annotated A–B clip',
            () => _addMarker(clip: true),
            icon: Icons.movie_creation_outlined,
          ),
          if (_native?.supports('snapshot') == true)
            _button(
              'Capture current frame',
              widget.onCapture,
              icon: Icons.photo_camera_outlined,
            ),
          if (_native?.supports('frame') == true)
            _button('Pause and step one frame', () async {
              await widget.player.pause();
              await _native!.nextFrame();
            }),
        ],
      ),
      if (tools.error != null) Text(tools.error!),
      if (chapters > 0)
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: 'Embedded chapter'),
          items: [
            for (var i = 0; i < chapters.clamp(0, 500); i++)
              DropdownMenuItem(value: i, child: Text('Chapter ${i + 1}')),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value != null)
                    _run(() async {
                      widget.onPositionIntent?.call();
                      await _native!.setChapter(value);
                    });
                },
        ),
      const Divider(),
      const Text(
        'Saved markers and clip annotations stay attached to this file/edition.',
      ),
      for (final entry in _timeline)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${videoTime(entry.start)}${entry.end == null ? '' : ' – ${videoTime(entry.end!)}'}',
                ),
                if (entry.note.isNotEmpty) Text(entry.note),
                Wrap(
                  spacing: 8,
                  children: [
                    _button(
                      'Go here',
                      () => widget.onSeek(Duration(milliseconds: entry.start)),
                    ),
                    if (entry.end != null)
                      _button('Loop clip', () async {
                        await tools.setLoop(
                          entry.start,
                          entry.end,
                          enabled: true,
                        );
                        await widget.onSeek(
                          Duration(milliseconds: entry.start),
                        );
                      }),
                    if (entry.end != null)
                      _button('Export annotation', () => _export(entry)),
                    if (entry.end != null &&
                        _native?.supports('clipExport') == true)
                      _button('Export video + annotation sidecar', () async {
                        final job = await _native!.exportClip(
                          Duration(milliseconds: entry.start),
                          Duration(milliseconds: entry.end!),
                        );
                        if (job == null) return;
                        await _native!.refresh();
                        final jobs =
                            (_native!.diagnostics['jobs'] as List? ?? [])
                                .whereType<Map>();
                        final output = jobs
                            .where((row) => row['id'] == job)
                            .firstOrNull;
                        final path = output?['path'];
                        if (path is String && path.isNotEmpty) {
                          final sidecar = File('$path.tangerine.json');
                          if (await sidecar.exists())
                            throw const FormatException(
                              'A clip annotation sidecar already exists beside this destination. Export the annotation separately.',
                            );
                          await sidecar.writeAsString(
                            jsonEncode({
                              'schema': 'tangerine.annotated-clip.v1',
                              'itemId': widget.item.id,
                              'fingerprint': widget.item.fingerprint,
                              'range': entry.toJson(),
                            }),
                          );
                        }
                      }),
                    _button('Remove', () async {
                      await _workspace.remove(entry.id);
                      await _load();
                    }, icon: Icons.delete_outline),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (_timeline.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Mark a chapter or save an annotated range to return to it later.',
          ),
        ),
    ]);
  }

  Future<void> _subtitleFile(bool secondary) async {
    if (secondary && widget.tools.subtitles.primary == null)
      throw const FormatException(
        'Load an external primary subtitle first for dual-language display.',
      );
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      allowMultiple: false,
    );
    final path = selection?.files.single.path;
    if (path == null) return;
    final document = await VideoSubtitleDocument.open(path);
    await widget.player.setSubtitleTrack(SubtitleTrack.no());
    if (!mounted) return;
    if (secondary) {
      widget.tools.subtitles.secondary = document;
    } else {
      widget.tools.subtitles.primary = document;
    }
    await widget.tools.save(
      primaryFile: secondary ? null : path,
      secondaryFile: secondary ? path : null,
    );
  }

  Future<void> _translate() async {
    final document = widget.tools.subtitles.primary;
    if (document == null)
      throw const FormatException('Choose a primary SRT/WebVTT file first.');
    final endpoint = TextEditingController(
      text:
          await widget.database.getSetting('player.video.translation.url') ??
          'http://localhost:5000/translate',
    );
    final source = TextEditingController(text: 'auto'),
        target = TextEditingController(text: 'en'),
        key = TextEditingController();
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Translate selected subtitles'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Only the selected subtitle text is sent to your configured LibreTranslate service. Up to 4,000 cues; no video upload. A service may charge for requests.',
                ),
                TextField(
                  controller: endpoint,
                  decoration: const InputDecoration(
                    labelText: 'Full /translate endpoint',
                  ),
                ),
                TextField(
                  controller: source,
                  decoration: const InputDecoration(
                    labelText: 'Source language code',
                  ),
                ),
                TextField(
                  controller: target,
                  decoration: const InputDecoration(
                    labelText: 'Target language code',
                  ),
                ),
                TextField(
                  controller: key,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API key (blank uses saved key)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send subtitle text and translate'),
          ),
        ],
      ),
    );
    final urlText = endpoint.text,
        sourceText = source.text.trim(),
        targetText = target.text.trim(),
        keyText = key.text;
    endpoint.dispose();
    source.dispose();
    target.dispose();
    key.dispose();
    if (accepted != true || !mounted) return;
    final url = VideoSubtitleTranslator.endpoint(urlText);
    final store = SecureCredentialStore(
      key:
          'tangerine.subtitle.translation.${sha256.convert(utf8.encode(url.toString()))}',
    );
    if (keyText.isNotEmpty) await store.write(keyText);
    await widget.database.setSetting(
      'player.video.translation.url',
      url.toString(),
    );
    _translator?.close();
    final translator = _translator = VideoSubtitleTranslator();
    try {
      final result = await translator.translate(
        document,
        url: url,
        source: sourceText,
        target: targetText,
        key: keyText.isEmpty ? await store.read() ?? '' : keyText,
        progress: (done, total) {
          if (mounted)
            setState(
              () => _translationProgress = 'Translated $done / $total cues',
            );
        },
      );
      if (!mounted) return;
      widget.tools.subtitles.secondary = result;
      await widget.tools.save(clearSecondary: true);
      _translationProgress = 'Translation ready. Export SRT to retain it.';
    } finally {
      translator.close();
    }
  }

  Widget _subtitlePage() {
    final p = widget.tools.subtitles;
    Widget slider(
      String title,
      double value,
      double min,
      double max,
      void Function(double) update,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title · ${value.toStringAsFixed(2)}'),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: _busy
              ? null
              : (v) {
                  setState(() => update(v));
                  p.changed();
                },
          onChangeEnd: (_) => _run(() => widget.tools.save()),
        ),
      ],
    );
    return _list([
      const Text(
        'Two external timed text files provide dual-language captions. Embedded/image-based subtitles continue through the native track picker. Turn off embedded captions when using this overlay.',
      ),
      SwitchListTile(
        title: const Text('External subtitle overlay'),
        value: p.enabled,
        onChanged: (v) {
          setState(() => p.enabled = v);
          p.changed();
          _run(() => widget.tools.save());
        },
      ),
      Wrap(
        spacing: 8,
        children: [
          _button('Load primary SRT / VTT', () => _subtitleFile(false)),
          _button('Load secondary SRT / VTT', () => _subtitleFile(true)),
          _button(
            'Translate primary into secondary',
            _translate,
            icon: Icons.translate,
          ),
          _button('Clear both overlays', () async {
            p.primary = null;
            p.secondary = null;
            await widget.tools.save(clearPrimary: true, clearSecondary: true);
          }),
          if (p.secondary != null)
            _button('Export secondary SRT', () async {
              final path = await FilePicker.platform.saveFile(
                fileName: 'Tangerine-translated.srt',
                type: FileType.custom,
                allowedExtensions: ['srt'],
              );
              if (path != null) {
                await File(path).writeAsString(p.secondary!.srt());
                await widget.tools.save(secondaryFile: path);
              }
            }),
        ],
      ),
      if (_translationProgress != null) Text(_translationProgress!),
      if (_busy && _translator != null)
        TextButton(
          onPressed: () => _translator?.close(),
          child: const Text('Cancel translation'),
        ),
      slider('Primary size', p.size, 12, 60, (v) => p.size = v),
      slider(
        'Secondary size',
        p.secondarySize,
        12,
        60,
        (v) => p.secondarySize = v,
      ),
      slider(
        'Primary timing offset (seconds)',
        p.delay / 1000,
        -60,
        60,
        (v) => p.delay = (v * 1000).round(),
      ),
      slider(
        'Secondary timing offset (seconds)',
        p.secondaryDelay / 1000,
        -60,
        60,
        (v) => p.secondaryDelay = (v * 1000).round(),
      ),
      const Text(
        'Positive delay shows captions later; negative delay shows them earlier.',
      ),
      slider(
        'Caption background opacity',
        p.background,
        0,
        1,
        (v) => p.background = v,
      ),
      DropdownButtonFormField<int>(
        initialValue: p.color,
        decoration: const InputDecoration(labelText: 'Primary text colour'),
        items: [
          for (final color in const {
            0xffffffff: 'White',
            0xffffe082: 'Warm yellow',
            0xffb2ebf2: 'Pale blue',
          }.entries)
            DropdownMenuItem(value: color.key, child: Text(color.value)),
        ],
        onChanged: (v) {
          if (v != null) {
            p.color = v;
            _run(() => widget.tools.save());
          }
        },
      ),
    ]);
  }

  Widget _audioPage() {
    final engine = _native,
        devices = (_native?.diagnostics['audioDevices'] as List? ?? [])
            .whereType<Map>()
            .toList();
    return _list([
      const Text(
        'Dialogue enhancement applies a gentle speech-band equalizer with headroom. Loudness normalization is a native filter and requires a player restart at the current position.',
      ),
      SwitchListTile(
        title: const Text('Enhance dialogue'),
        value: _active.dialogue,
        onChanged: _busy
            ? null
            : (v) => _run(() => _customProfile(dialogue: v)),
      ),
      SwitchListTile(
        title: const Text('Normalize loudness'),
        value: _active.normalize,
        onChanged: _busy
            ? null
            : (v) => _run(() => _customProfile(normalize: v)),
      ),
      if (Platform.isIOS && engine?.supports('routePicker') == true)
        const ListTile(
          title: Text('System audio route'),
          subtitle: Text('Speaker, Bluetooth or AirPlay'),
          trailing: SizedBox(
            width: 48,
            height: 48,
            child: UiKitView(
              viewType: 'tangerine/vlc-route-picker',
              creationParams: {'routePicker': true},
              creationParamsCodec: StandardMessageCodec(),
            ),
          ),
        ),
      if (engine?.supports('devices') == true) ...[
        const Text(
          'Route this player independently. An unavailable device remains an explicit error; System default is always available.',
        ),
        _button('Use system default', () async {
          await engine!.setOutputDevice('');
          _active = _active.copyWith(outputDevice: '');
        }),
        for (final device in devices)
          ListTile(
            title: Text('${device['name'] ?? device['title'] ?? device['id']}'),
            leading: const Icon(Icons.speaker),
            onTap: _busy
                ? null
                : () => _run(() async {
                    final id = '${device['id']}';
                    await engine!.setOutputDevice(id);
                    _active = _active.copyWith(outputDevice: id);
                  }),
          ),
      ] else
        const Text(
          'Output routing is managed by the operating system on this platform. Use the system audio route picker.',
        ),
      if (engine?.supports('audioDelay') == true)
        _button('Set audio synchronization offset', () async {
          final value = await _text(
            'Audio delay, seconds (−60 to 60)',
            initial: '0',
          );
          if (value == null) return;
          final number = double.tryParse(value);
          if (number == null || !number.isFinite || number.abs() > 60)
            throw const FormatException(
              'Enter a finite delay from −60 to 60 seconds.',
            );
          await engine!.setPicture({'audioDelay': number});
        }),
      const Text(
        'Save a named copy under Profiles after choosing a route to reuse it.',
      ),
    ]);
  }

  Future<Item?> _comparisonItem() => showDialog<Item>(
    context: context,
    builder: (_) =>
        _ComparisonChooser(database: widget.database, excluded: widget.item.id),
  );
  Widget _windowsPage() => _list([
    const Text(
      'Independent windows have their own engine, queue and transport. Comparison uses two temporary decoders and leaves normal watch progress unchanged.',
    ),
    if (DesktopPlaybackWindows.available)
      _button('Open independent playback window', () async {
        await DesktopPlaybackWindows.open(
          widget.item.id,
          database: widget.database,
          position: widget.player.state.position.inMilliseconds / 1000,
        );
      }, icon: Icons.open_in_new),
    _button('Picture-in-picture inside Tangerine', () async {
      Navigator.pop(context);
      widget.onPip();
    }, icon: Icons.picture_in_picture_alt),
    if (_native?.supports('mini') == true)
      _button(
        'Floating desktop picture-in-picture',
        _native!.toggleMini,
        icon: Icons.picture_in_picture,
      ),
    _button('Compare with another video / edition', () async {
      final second = await _comparisonItem();
      if (second == null || !mounted) return;
      final resume = widget.player.state.playing;
      await widget.player.pause();
      try {
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => VideoComparisonScreen(
              database: widget.database,
              client: widget.client,
              first: widget.item,
              second: second,
              position: widget.player.state.position,
              volume: widget.player.state.volume,
              rate: widget.player.state.rate,
            ),
          ),
        );
      } finally {
        if (mounted && resume) await widget.player.play();
      }
    }, icon: Icons.compare),
    const Text(
      'In-app picture-in-picture stays in Tangerine. The floating macOS player can stay above other applications. Mobile system picture-in-picture is not advertised by this backend.',
    ),
  ]);
  List<String> _explanations() {
    final state = widget.player.state;
    final statistics = (_native?.diagnostics['statistics'] as Map?) ?? {};
    double value(String key) {
      final alias = {
        'Lost pictures': 'lostPictures',
        'Displayed pictures': 'displayedPictures',
      }[key];
      return double.tryParse('${statistics[key] ?? statistics[alias] ?? 0}') ??
          0;
    }

    final lost = value('Lost pictures'), shown = value('Displayed pictures');
    return [
      if (state.buffering)
        'Buffering for ${_bufferingSince == null ? 0 : DateTime.now().difference(_bufferingSince!).inSeconds}s. The input is waiting for data. Check source availability or network speed; a larger cache may help intermittent delivery.',
      if (state.playing &&
          !state.buffering &&
          DateTime.now().difference(_advanced).inSeconds > 4)
        'The playback clock has stalled. This can indicate a decoder/output problem; try pausing, a software decoder, or another file/edition.',
      if (lost > 5 && lost / (lost + shown + 1) > .03)
        'More than 3% of reported pictures were lost. This is a decoder/rendering pressure clue, not proof of network loss. Close comparison windows or use a lower-resolution edition.',
      if (state.width == null || state.width == 0)
        'Video geometry is not reported yet. The source may still be opening, may be audio-only, or may use an unsupported video codec.',
      if (_native?.diagnostics['error'] == true)
        'The native engine reports a playback failure. Check file access, codec/container support and whether the source can be read. The catalog extension alone does not establish codec support.',
      if (!state.buffering &&
          state.playing &&
          DateTime.now().difference(_advanced).inSeconds <= 4)
        'The playback clock is advancing without a buffering flag. No buffering fault is currently reported.',
      'Hardware acceleration, HDR output and exact codec support are only established when the backend reports them. A software texture path or a preference is not proof of accelerated decoding.',
    ];
  }

  Widget _diagnosticsPage() => _list([
    Text(
      widget.player.backendName,
      style: Theme.of(context).textTheme.titleLarge,
    ),
    for (final explanation in _explanations())
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(explanation),
      ),
    Wrap(
      spacing: 8,
      children: [
        _button(
          'Use 5-second network cache and reopen',
          () => _customProfile(cache: 5000),
        ),
        _button(
          'Request software decoding and reopen',
          () => _customProfile(software: true),
        ),
        _button(
          'Copy sanitized diagnostics',
          () => Clipboard.setData(
            ClipboardData(
              text: const JsonEncoder.withIndent('  ').convert({
                'backend': widget.player.backendName,
                'positionMs': widget.player.state.position.inMilliseconds,
                'durationMs': widget.player.state.duration.inMilliseconds,
                'buffering': widget.player.state.buffering,
                'width': widget.player.state.width,
                'height': widget.player.state.height,
                'capabilities': _native?.capabilities.toList(),
                'statistics': _native?.diagnostics['statistics'],
                'explanations': _explanations(),
              }),
            ),
          ),
        ),
      ],
    ),
    _button('Open file format and technical details', () async {
      await context.push('/details/${Uri.encodeComponent(widget.item.id)}');
    }),
    for (final entry
        in ((_native?.diagnostics['statistics'] as Map?) ?? {}).entries)
      ListTile(title: Text('${entry.key}'), subtitle: Text('${entry.value}')),
    if ((_native?.diagnostics['statistics'] as Map?)?.isNotEmpty != true)
      const Text(
        'This backend does not report detailed input/decoder counters.',
      ),
  ]);
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 6,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Advanced video'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Profiles'),
            Tab(text: 'Timeline & clips'),
            Tab(text: 'Subtitles'),
            Tab(text: 'Audio'),
            Tab(text: 'Windows & compare'),
            Tab(text: 'Diagnostics'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _profilePage(),
          _timelinePage(),
          _subtitlePage(),
          _audioPage(),
          _windowsPage(),
          _diagnosticsPage(),
        ],
      ),
    ),
  );
}

class _ComparisonChooser extends StatefulWidget {
  const _ComparisonChooser({required this.database, required this.excluded});
  final AppDatabase database;
  final String excluded;
  @override
  State<_ComparisonChooser> createState() => _ChooserState();
}

class _ChooserState extends State<_ComparisonChooser> {
  final _search = TextEditingController();
  List<Item> _rows = [];
  int _page = 0, _generation = 0;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ++_generation;
    setState(() => _loading = true);
    try {
      final query = widget.database.select(widget.database.items)
        ..where(
          (t) =>
              t.itemType.equals('video') &
              t.unavailable.equals(false) &
              t.id.equals(widget.excluded).not() &
              (t.title.contains(_search.text.trim()) |
                  t.userTitle.contains(_search.text.trim())),
        )
        ..orderBy([
          (t) => drift.OrderingTerm.asc(t.title),
          (t) => drift.OrderingTerm.asc(t.id),
        ])
        ..limit(40, offset: _page * 40);
      final rows = await query.get();
      if (mounted && token == _generation)
        setState(() {
          _rows = rows;
          _loading = false;
        });
    } catch (_) {
      if (mounted && token == _generation)
        setState(() {
          _error = 'Videos could not be loaded.';
          _loading = false;
        });
    }
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose comparison B'),
    content: SizedBox(
      width: 560,
      height: 440,
      child: Column(
        children: [
          TextField(
            controller: _search,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Search video titles'),
            onSubmitted: (_) {
              _page = 0;
              _load();
            },
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          Expanded(
            child: ListView(
              children: [
                for (final item in _rows)
                  ListTile(
                    title: Text(item.userTitle ?? item.title),
                    subtitle: Text(item.filename),
                    onTap: () => Navigator.pop(context, item),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _page == 0 || _loading
                    ? null
                    : () {
                        _page--;
                        _load();
                      },
                child: const Text('Previous'),
              ),
              Text('Page ${_page + 1}'),
              TextButton(
                onPressed: _rows.length < 40 || _loading
                    ? null
                    : () {
                        _page++;
                        _load();
                      },
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
