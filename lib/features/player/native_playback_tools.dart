import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/db/app_database.dart';
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
    final value = await database.getSetting('playback.effects.$itemId');
    if (value == null) return NativePlaybackSettings();
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
      ]) {
        final entry = (json['picture'] as Map?)?[key];
        if (entry is num && entry.isFinite) picture[key] = entry.toDouble();
      }
      return NativePlaybackSettings(
        equalizer: json['equalizer'] == true,
        preamp: (json['preamp'] as num).toDouble().clamp(-20, 20),
        bands: bands,
        picture: picture,
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
  });
  final NativeVlcEngine engine;
  final AppDatabase database;
  final String itemId;
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
    final settings = _settings!;
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Equalizer'),
                    value: settings.equalizer,
                    onChanged: (value) =>
                        _change(() => settings.equalizer = value),
                  ),
                  if (settings.equalizer) ...[
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
                  const Divider(),
                  for (final key in [
                    'brightness',
                    'contrast',
                    'saturation',
                    'gamma',
                  ])
                    _slider(
                      key[0].toUpperCase() + key.substring(1),
                      (settings.picture[key] as num?)?.toDouble() ?? 1,
                      key == 'gamma' ? .01 : 0,
                      key == 'gamma'
                          ? 10
                          : key == 'saturation'
                          ? 3
                          : 2,
                      (value) => _change(() => settings.picture[key] = value),
                    ),
                  _slider(
                    'Audio delay (seconds)',
                    (settings.picture['audioDelay'] as num?)?.toDouble() ?? 0,
                    -5,
                    5,
                    (value) =>
                        _change(() => settings.picture['audioDelay'] = value),
                  ),
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
                  TextButton(
                    onPressed: () => _change(() {
                      settings.equalizer = false;
                      settings.preamp = 0;
                      settings.bands.fillRange(0, 10, 0);
                      settings.picture.clear();
                    }),
                    child: const Text('Reset effects for this title'),
                  ),
                ],
              ),
      ),
    );
  }
}
