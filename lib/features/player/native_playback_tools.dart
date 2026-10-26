import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/db/app_database.dart';
import '../../domain/services/player_behavior_preferences.dart';
import '../../data/playback/playback_engine.dart';
import '../../shared/widgets/study_ui.dart';

class NativePlaybackSettings {
  NativePlaybackSettings({
    this.equalizer = false,
    this.preamp = 0,
    List<double>? bands,
    Map<String, Object?>? picture,
  }) : bands = bands ?? List.filled(10, 0),
       picture = picture ?? {};
  bool equalizer;
  double preamp;
  final List<double> bands;
  final Map<String, Object?> picture;

  static Future<NativePlaybackSettings> load(
    AppDatabase database,
    String itemId,
  ) async {
    final value =
        await database.getSetting('playback.effects.$itemId') ??
        await database.getSetting('player.profile.effects');
    if (value == null || value == 'null') {
      try {
        return NativePlaybackSettings(
          picture: PlayerPicturePreferences.project(
            jsonDecode(
                  await database.getSetting('player.native.preferences') ??
                      '{}',
                )
                as Map,
          ),
        );
      } catch (_) {
        return NativePlaybackSettings();
      }
    }
    try {
      final json = jsonDecode(value) as Map;
      final bands = (json['bands'] as List)
          .map((v) => (v as num).toDouble().clamp(-20.0, 20.0))
          .toList();
      if (bands.length != 10) return NativePlaybackSettings();
      final picture = <String, Object?>{};
      for (final key in [
        'brightness',
        'contrast',
        'saturation',
        'gamma',
        'audioDelay',
        'subtitleDelay',
        'hue',
        'zoom',
      ]) {
        final entry = (json['picture'] as Map?)?[key];
        if (entry is num && entry.isFinite) picture[key] = entry.toDouble();
      }
      for (final key in ['aspect', 'crop', 'deinterlaceMode']) {
        final value = (json['picture'] as Map?)?[key];
        if (value is String &&
            value.length <= 128 &&
            !value.contains(RegExp(r'[\x00-\x1f]')))
          picture[key] = value;
      }
      final validatedPicture = PlayerPicturePreferences.project(picture);
      return NativePlaybackSettings(
        equalizer: json['equalizer'] == true,
        preamp: (json['preamp'] as num).toDouble().clamp(-20, 20),
        bands: bands,
        picture: validatedPicture,
      );
    } catch (_) {
      return NativePlaybackSettings();
    }
  }

  Future<void> apply(NativeVlcEngine engine) async {
    await engine.setEqualizer(enabled: equalizer, preamp: preamp, bands: bands);
    await engine.setPicture(picture);
  }

  Future<void> save(AppDatabase database, String itemId) => database.setSetting(
    'playback.effects.$itemId',
    jsonEncode({
      'equalizer': equalizer,
      'preamp': preamp,
      'bands': bands,
      'picture': picture,
    }),
  );
}

class NativePlaybackTools extends StatefulWidget {
  const NativePlaybackTools({
    super.key,
    required this.engine,
    required this.database,
    required this.itemId,
    this.video = true,
  });
  final NativeVlcEngine engine;
  final AppDatabase database;
  final String itemId;
  final bool video;
  @override
  State<NativePlaybackTools> createState() => _NativePlaybackToolsState();
}

class _NativePlaybackToolsState extends State<NativePlaybackTools> {
  NativePlaybackSettings? _settings;
  String? _error;
  Future<void> _pending = Future.value();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await NativePlaybackSettings.load(
      widget.database,
      widget.itemId,
    );
    if (mounted) setState(() => _settings = settings);
  }

  void _change(VoidCallback update) {
    setState(update);
    final current = _settings!;
    final settings = NativePlaybackSettings(
      equalizer: current.equalizer,
      preamp: current.preamp,
      bands: List.of(current.bands),
      picture: Map.of(current.picture),
    );
    // Preserve slider order across asynchronous native calls and durable saves.
    _pending = _pending
        .then((_) async {
          await settings.apply(widget.engine);
          await settings.save(widget.database, widget.itemId);
        })
        .catchError((Object error) {
          if (mounted) {
            setState(
              () => _error = 'These effects could not be applied. Try again.',
            );
          }
        });
  }

  Widget _slider(
    String title,
    double value,
    double minimum,
    double maximum,
    ValueChanged<double> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$title · ${value.toStringAsFixed(1)}'),
      Slider(
        value: value.clamp(minimum, maximum),
        min: minimum,
        max: maximum,
        onChanged: onChanged,
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final chapters =
        (widget.engine.diagnostics['chapters'] as num?)?.toInt() ?? 0;
    return StudyModalFrame(
      title: 'Playback tools',
      icon: Icons.tune,
      description: widget.engine.backendName,
      primaryAction: FilledButton(
        onPressed: () async {
          await _pending;
          if (context.mounted) Navigator.pop(context);
        },
        child: const Text('Done'),
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .55,
        child: settings == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  if (_error != null) Text(_error!),
                  if (chapters > 0)
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Chapter'),
                      initialValue:
                          (widget.engine.diagnostics['chapter'] as int? ?? 0)
                              .clamp(0, chapters - 1),
                      items: [
                        for (var i = 0; i < chapters; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text('Chapter ${i + 1}'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) widget.engine.setChapter(value);
                      },
                    ),
                  if (widget.engine.supports('equalizer'))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Equalizer'),
                      value: settings.equalizer,
                      onChanged: (value) =>
                          _change(() => settings.equalizer = value),
                    ),
                  if (settings.equalizer &&
                      widget.engine.supports('equalizer')) ...[
                    _slider(
                      'Preamp (dB)',
                      settings.preamp,
                      -20,
                      20,
                      (value) => _change(() => settings.preamp = value),
                    ),
                    for (var i = 0; i < 10; i++)
                      _slider(
                        const [
                          '60 Hz',
                          '170 Hz',
                          '310 Hz',
                          '600 Hz',
                          '1 kHz',
                          '3 kHz',
                          '6 kHz',
                          '12 kHz',
                          '14 kHz',
                          '16 kHz',
                        ][i],
                        settings.bands[i],
                        -20,
                        20,
                        (value) => _change(() => settings.bands[i] = value),
                      ),
                  ],
                  if (widget.video) ...[
                    for (final field in {
                      'aspect': 'Aspect ratio',
                      'crop': 'Crop',
                    }.entries)
                      if (widget.engine.supports(field.key))
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            '${field.key}:${settings.picture[field.key]}',
                          ),
                          initialValue:
                              (settings.picture[field.key] as String?) ?? '',
                          decoration: InputDecoration(labelText: field.value),
                          items: [
                            for (final value in [
                              '',
                              '16:9',
                              '4:3',
                              '21:9',
                              '1:1',
                              '16:10',
                              '2.35:1',
                              if (settings.picture[field.key] is String &&
                                  ![
                                    '',
                                    '16:9',
                                    '4:3',
                                    '21:9',
                                    '1:1',
                                    '16:10',
                                    '2.35:1',
                                  ].contains(settings.picture[field.key]))
                                settings.picture[field.key] as String,
                            ])
                              DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value.isEmpty ? 'Source / automatic' : value,
                                ),
                              ),
                          ],
                          onChanged: (value) => _change(
                            () => settings.picture[field.key] = value ?? '',
                          ),
                        ),
                    if (widget.engine.supports('zoom'))
                      _slider(
                        'Video scale · 0 means automatic',
                        (settings.picture['zoom'] as num?)?.toDouble() ?? 0,
                        0,
                        5,
                        (value) =>
                            _change(() => settings.picture['zoom'] = value),
                      ),
                    if (widget.engine.supports('deinterlace'))
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'deinterlace:${settings.picture['deinterlaceMode']}',
                        ),
                        initialValue:
                            (settings.picture['deinterlaceMode'] as String?) ??
                            'off',
                        decoration: const InputDecoration(
                          labelText: 'Deinterlace',
                        ),
                        items: [
                          for (final value in [
                            'off',
                            'blend',
                            'bob',
                            'linear',
                            'yadif',
                            'yadif2x',
                            if (settings.picture['deinterlaceMode'] is String &&
                                ![
                                  'off',
                                  'blend',
                                  'bob',
                                  'yadif',
                                  'yadif2x',
                                ].contains(settings.picture['deinterlaceMode']))
                              settings.picture['deinterlaceMode'] as String,
                          ])
                            DropdownMenuItem(value: value, child: Text(value)),
                        ],
                        onChanged: (value) => _change(
                          () => settings.picture['deinterlaceMode'] =
                              value ?? 'off',
                        ),
                      ),
                    if (widget.engine.supports('hue'))
                      _slider(
                        'Hue',
                        (settings.picture['hue'] as num?)?.toDouble() ?? 0,
                        -180,
                        180,
                        (value) =>
                            _change(() => settings.picture['hue'] = value),
                      ),
                    const Divider(),
                    for (final key in [
                      'brightness',
                      'contrast',
                      'saturation',
                      'gamma',
                    ])
                      if (widget.engine.supports(key))
                        _slider(
                          key[0].toUpperCase() + key.substring(1),
                          (settings.picture[key] as num?)?.toDouble() ?? 1,
                          key == 'gamma' ? .01 : 0,
                          key == 'gamma'
                              ? 10
                              : key == 'saturation'
                              ? 3
                              : 2,
                          (value) =>
                              _change(() => settings.picture[key] = value),
                        ),
                  ],
                  _slider(
                    'Audio delay (seconds)',
                    (settings.picture['audioDelay'] as num?)?.toDouble() ?? 0,
                    -5,
                    5,
                    (value) =>
                        _change(() => settings.picture['audioDelay'] = value),
                  ),
                  if (widget.video)
                    _slider(
                      'Subtitle delay (seconds)',
                      (settings.picture['subtitleDelay'] as num?)?.toDouble() ??
                          0,
                      -5,
                      5,
                      (value) => _change(
                        () => settings.picture['subtitleDelay'] = value,
                      ),
                    ),
                  _DeviceDiagnostics(
                    engine: widget.engine,
                    database: widget.database,
                  ),
                  TextButton(
                    onPressed: () => _change(() {
                      settings.equalizer = false;
                      settings.preamp = 0;
                      settings.bands.fillRange(0, 10, 0);
                      settings.picture
                        ..clear()
                        ..addAll({
                          'brightness': 1,
                          'contrast': 1,
                          'saturation': 1,
                          'gamma': 1,
                          'hue': 0,
                          'aspect': '',
                          'crop': '',
                          'zoom': 0,
                          'deinterlaceMode': 'off',
                          'audioDelay': 0,
                          'subtitleDelay': 0,
                        });
                    }),
                    child: const Text('Reset effects for this title'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DeviceDiagnostics extends StatefulWidget {
  const _DeviceDiagnostics({required this.engine, required this.database});
  final AppDatabase database;
  final NativeVlcEngine engine;
  @override
  State<_DeviceDiagnostics> createState() => _DeviceDiagnosticsState();
}

class _DeviceDiagnosticsState extends State<_DeviceDiagnostics> {
  Timer? _timer;
  String? _error;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.engine.diagnostics,
        devices = (data['audioDevices'] as List? ?? []).cast<Map>();
    final selected = data['audioDevice'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) Text(_error!),
        if (widget.engine.supports('routePicker'))
          const ListTile(
            title: Text('Audio output'),
            subtitle: Text(
              'Choose a system speaker, Bluetooth or AirPlay route.',
            ),
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
        if (widget.engine.supports('devices'))
          DropdownButtonFormField<String>(
            key: ValueKey('device:$selected:${devices.length}'),
            initialValue: devices.any((d) => d['id'] == selected)
                ? selected
                : '',
            decoration: const InputDecoration(labelText: 'Audio output device'),
            items: [
              const DropdownMenuItem(value: '', child: Text('System default')),
              for (final device in devices)
                if (device['id'] != '')
                  DropdownMenuItem(
                    value: device['id'] as String,
                    child: Text('${device['title']}'),
                  ),
            ],
            onChanged: (value) async {
              try {
                await widget.engine.setOutputDevice(value ?? '');
                await widget.database.transaction(() async {
                  final prefs = Map<String, dynamic>.from(
                    jsonDecode(
                          await widget.database.getSetting(
                                'player.native.preferences',
                              ) ??
                              '{}',
                        )
                        as Map,
                  );
                  prefs['outputDevice'] = value ?? '';
                  await widget.database.setSetting(
                    'player.native.preferences',
                    jsonEncode(prefs),
                  );
                });
                if (mounted) setState(() => _error = null);
              } catch (_) {
                if (mounted)
                  setState(
                    () => _error =
                        'The output device is unavailable. Refresh devices and try again.',
                  );
              }
            },
          ),
        if (widget.engine.supports('devices'))
          TextButton(
            onPressed: () async {
              try {
                await widget.engine.refresh();
                if (mounted) setState(() => _error = null);
              } catch (_) {
                if (mounted)
                  setState(
                    () => _error = 'Output devices could not be refreshed.',
                  );
              }
            },
            child: const Text('Refresh output devices'),
          ),
        if (widget.engine.supports('diagnostics'))
          ExpansionTile(
            title: const Text('Live player diagnostics'),
            children: [
              ListTile(
                title: Text('${data['version'] ?? widget.engine.backendName}'),
                subtitle: Text(
                  '${data['width'] ?? 0} × ${data['height'] ?? 0} · ${widget.engine.state.rate}× · ${widget.engine.state.position.inSeconds} / ${widget.engine.state.duration.inSeconds} seconds',
                ),
              ),
              for (final key in ['metadata', 'statistics'])
                if (data[key] is Map)
                  for (final entry in (data[key] as Map).entries)
                    ListTile(
                      dense: true,
                      title: Text('${entry.key}'),
                      subtitle: SelectableText('${entry.value}'),
                    ),
            ],
          ),
      ],
    );
  }
}
