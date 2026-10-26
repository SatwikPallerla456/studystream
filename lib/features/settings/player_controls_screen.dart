import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/app_providers.dart';
import '../../data/db/app_database.dart';
import '../../domain/services/player_controls_repository.dart';
import '../../domain/services/player_profile_repository.dart';
import '../../domain/services/player_library_repository.dart';
import '../../domain/services/player_behavior_preferences.dart';
import '../../domain/services/legacy_player_preferences.dart';
import '../player/desktop_playback_windows.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/study_ui.dart';

class PlayerControlsScreen extends ConsumerStatefulWidget {
  const PlayerControlsScreen({super.key});
  @override
  ConsumerState<PlayerControlsScreen> createState() =>
      _PlayerControlsScreenState();
}

class _PlayerControlsScreenState extends ConsumerState<PlayerControlsScreen> {
  PlayerControls? _controls;
  final _local = <String, TextEditingController>{},
      _global = <String, TextEditingController>{};
  final _native = <String, String>{};
  List<Map> _fields = [];
  int _skip = 10, _step = 5;
  String? _error;
  bool _saving = false;
  List<Map<String, dynamic>> _profiles = [];
  String? _importSpeed;
  Map<String, Object?> _importPicture = {};
  Future<void> _saveImportedPicture(AppDatabase db) async {
    if (_importPicture.isEmpty) return;
    final raw = jsonDecode(
      await db.getSetting('player.profile.effects') ?? 'null',
    );
    final effects = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{
            'equalizer': false,
            'preamp': 0,
            'bands': List.filled(10, 0.0),
          };
    effects['picture'] = {
      ...Map<String, dynamic>.from(effects['picture'] as Map? ?? {}),
      ..._importPicture,
    };
    await db.setSetting('player.profile.effects', jsonEncode(effects));
  }

  List<Map<String, dynamic>> _stagedProfiles = [];
  final _interactions = <String, dynamic>{};
  PlayerControls _currentControls() => PlayerControls.fromJson({
    ...?_controls?.toJson(),
    ..._interactions,
    'local': _local.map((k, c) => MapEntry(k, c.text)),
    'global': _global.map((k, c) => MapEntry(k, c.text)),
    'skipSeconds': _skip,
    'volumeStep': _step,
  });
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._local.values, ..._global.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveQueuePolicy() async {
    final queue = ref.read(playerLibraryRepositoryProvider),
        current = await ref.read(playerLibraryRepositoryProvider).load();
    if (_native['repeat'] != null && _native['repeat'] != current.repeat.name)
      await queue.setRepeat(
        QueueRepeat.values.firstWhere(
          (v) => v.name == _native['repeat'],
          orElse: () => QueueRepeat.off,
        ),
      );
    if (_native['shuffle'] != null &&
        (_native['shuffle'] == 'true') != current.shuffle)
      await queue.setShuffle(_native['shuffle'] == 'true');
  }

  Future<void> _load() async {
    final repository = PlayerControlsRepository(ref.read(appDatabaseProvider));
    final controls = await repository.load();
    final native = await repository.nativePreferences();
    final queue = await ref.read(playerLibraryRepositoryProvider).load();
    native['repeat'] = queue.repeat.name;
    native['shuffle'] = '${queue.shuffle}';
    List<Map> fields = [];
    if (Platform.isMacOS) {
      try {
        fields =
            (await const MethodChannel(
              'tangerine/playback',
            ).invokeListMethod<Map>('preferences.catalog') ??
            []);
      } on PlatformException {
        /* Local controls remain available if no native bridge is present. */
      } on MissingPluginException {
        /* Widget test and unsupported platform boundary. */
      }
    }
    final profiles = await PlayerProfileRepository(
      ref.read(appDatabaseProvider),
    ).load();
    if (!mounted) return;
    for (final action in playerActionTitles.keys) {
      if (_local.containsKey(action)) {
        _local[action]!.text = controls.local[action] ?? '';
        _global[action]!.text = controls.global[action] ?? '';
      } else {
        _local[action] = TextEditingController(
          text: controls.local[action] ?? '',
        );
        _global[action] = TextEditingController(
          text: controls.global[action] ?? '',
        );
      }
    }
    setState(() {
      _controls = controls;
      _native.addAll(native);
      _fields = fields.isEmpty ? portableEnginePreferenceFields : fields;
      _skip = controls.skipSeconds;
      _step = controls.volumeStep;
      _profiles = profiles;
      _interactions
        ..clear()
        ..addAll(controls.toJson());
    });
  }

  void _validateNative(Map<String, String> values) {
    PlayerBehaviorPreferences.project(values);
    PlayerPicturePreferences.project(values);
    for (final field in _fields) {
      final key = field['key'] as String, value = values[field['key']];
      if (value == null) continue;
      if (value.length > 256 || value.contains(RegExp(r'[\x00-\x1f]')))
        throw FormatException('Invalid value for ${field['title']}');
      if (field['type'] == 'toggle' && !{'true', 'false'}.contains(value))
        throw FormatException('Invalid switch for $key');
      if (field['type'] == 'choice' &&
          !(field['choices'] as List).contains(value))
        throw FormatException('Unsupported choice for ${field['title']}');
      if (field['type'] == 'slider') {
        final n = double.tryParse(value);
        if (n == null ||
            !n.isFinite ||
            n < (field['min'] as num) ||
            n > (field['max'] as num))
          throw FormatException('Invalid amount for ${field['title']}');
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = ref.read(appDatabaseProvider);
      await db.transaction(() async {
        await PlayerControlsRepository(db).save(_currentControls());
        await PlayerProfileRepository(db).importLegacy(_stagedProfiles);
        _validateNative(_native);
        await db.setSetting('player.native.preferences', jsonEncode(_native));
        await _saveImportedPicture(db);
        await _saveQueuePolicy();
        if (_importSpeed != null) {
          await db.setSetting('defaultPlaybackSpeed', _importSpeed!);
        }
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Player preferences could not be saved.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importPreferences() async {
    try {
      Map<String, dynamic>? data;
      if (Platform.isMacOS) {
        data = await const MethodChannel(
          'tangerine/playback',
        ).invokeMapMethod<String, dynamic>('preferences.importPreview');
        if (data != null) {
          final projected = LegacyPlayerPreferences.preview({
            'preferences': data['preferences'] ?? {},
            'profiles': data['profiles'] ?? [],
          }, engineKeys: _fields.map((f) => f['key'] as String).toSet());
          data['stagedProfiles'] = projected['profiles'];
          data['preferences'] = projected['preferences'];
        }
      } else {
        final selected = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        final path = selected?.files.single.path;
        if (path == null) return;
        data = await LegacyPlayerPreferences.file(
          File(path),
          engineKeys: _fields.map((f) => f['key'] as String).toSet(),
        );
        data['stagedProfiles'] = data['profiles'];
        data['source'] = path.split(RegExp(r'[/\\]')).last;
      }
      final preview = data;
      if (preview == null || !mounted) return;
      final native = Map<String, String>.from(preview['preferences'] as Map);
      _validateNative(native);
      for (final profile in preview['stagedProfiles'] as List? ?? []) {
        _validateNative(
          Map<String, String>.from((profile as Map)['native'] as Map),
        );
      }
      final local = Map<String, String>.from(preview['local'] as Map),
          global = Map<String, String>.from(preview['global'] as Map);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import supported MyVLC settings?'),
          content: Text(
            '${native.length} supported preferences and ${(preview['stagedProfiles'] as List? ?? []).length} profiles from ${preview['source']}. Supported shortcuts will be staged for review. Credentials, account settings, source files and pairing settings stay unchanged. Press Save on the controls page to apply.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Review settings'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      setState(() {
        _native.addAll(native);
        _importPicture = PlayerPicturePreferences.project(native);
        _stagedProfiles = (preview['stagedProfiles'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        for (final key in ['skipVeryShort', 'skipMedium', 'skipLong']) {
          final value = double.tryParse(native[key] ?? '')?.round();
          if (value != null)
            _interactions[{
                  'skipVeryShort': 'veryShortSkip',
                  'skipMedium': 'mediumSkip',
                  'skipLong': 'longSkip',
                }[key]!] =
                value;
        }
        _skip = double.tryParse(native['skipShort'] ?? '')?.round() ?? _skip;
        _step = double.tryParse(native['volumeStep'] ?? '')?.round() ?? _step;
        for (final entry in {
          'singleClick': 'singleClick',
          'doubleClick': 'doubleClick',
          'scroll': 'verticalScroll',
          'horizontalScroll': 'horizontalScroll',
        }.entries) {
          final value = native[entry.key];
          if (value != null)
            _interactions[entry.value] =
                {
                  'Nothing': 'none',
                  'Play / Pause': 'playPause',
                  'Toggle fullscreen': 'fullscreen',
                  'Volume': 'volume',
                  'Seek': 'seek',
                }[value] ??
                'none';
        }
        if (native['reverseScroll'] != null)
          _interactions['reverseScroll'] = native['reverseScroll'] == 'true';
        for (final action in playerActionTitles.keys) {
          if (local.containsKey(action)) _local[action]!.text = local[action]!;
          if (global.containsKey(action)) {
            _global[action]!.text = global[action]!;
          }
        }
        final speed = double.tryParse(preview['speed'] as String? ?? '');
        if (speed != null && speed.isFinite && speed >= .25 && speed <= 4) {
          _importSpeed = speed.toString();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Choose a MyVLC preference JSON or exported preferences plist. The original file has been kept.',
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    var name = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save player profile'),
        content: TextField(
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Profile name'),
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save profile'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      final db = ref.read(appDatabaseProvider),
          profiles = PlayerProfileRepository(ref.read(appDatabaseProvider));
      await db.transaction(() async {
        await PlayerControlsRepository(db).save(_currentControls());
        _validateNative(_native);
        await db.setSetting('player.native.preferences', jsonEncode(_native));
        await _saveImportedPicture(db);
        await _saveQueuePolicy();
        if (_importSpeed != null) {
          await db.setSetting('defaultPlaybackSpeed', _importSpeed!);
        }
        await profiles.save(name);
      });
      final loaded = await profiles.load();
      if (mounted) setState(() => _profiles = loaded);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Profile could not be saved.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: 'Player controls & engine',
      showBack: true,
      actions: [
        TextButton(
          onPressed: _saving || _controls == null ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
    body: _controls == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null) Text(_error!),
              const Text(
                'Changes apply when the player next opens. Global shortcuts run only while a native player is open.',
              ),
              Text('Seek amount: $_skip seconds'),
              Slider(
                value: _skip.toDouble(),
                min: 1,
                max: 120,
                divisions: 119,
                onChanged: (value) => setState(() => _skip = value.round()),
              ),
              Text('Volume step: $_step%'),
              Slider(
                value: _step.toDouble(),
                min: 1,
                max: 25,
                divisions: 24,
                onChanged: (value) => setState(() => _step = value.round()),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _saveProfile,
                    child: const Text('Save player profile'),
                  ),
                  OutlinedButton(
                    onPressed: _importPreferences,
                    child: const Text('Import MyVLC settings / profiles'),
                  ),
                  if (_stagedProfiles.isNotEmpty)
                    Text(
                      '${_stagedProfiles.length} profiles staged · Save to import',
                    ),
                ],
              ),
              for (final profile in _profiles)
                ListTile(
                  title: Text(profile['title'] as String),
                  onTap: () async {
                    try {
                      _validateNative(
                        Map<String, String>.from(profile['native'] as Map),
                      );
                    } on FormatException catch (error) {
                      setState(() => _error = error.message);
                      return;
                    }
                    await PlayerProfileRepository(
                      ref.read(appDatabaseProvider),
                      queueNamespace: ref
                          .read(playerLibraryRepositoryProvider)
                          .queueNamespace,
                    ).apply(profile['id'] as String);
                    if (!mounted) return;
                    _native.clear();
                    await _load();
                  },
                  trailing: IconButton(
                    tooltip: 'Delete profile',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final repository = PlayerProfileRepository(
                        ref.read(appDatabaseProvider),
                      );
                      await repository.delete(profile['id'] as String);
                      final values = await repository.load();
                      if (mounted) setState(() => _profiles = values);
                    },
                  ),
                ),
              const SizedBox(height: 16),
              StudySection(
                title: 'Keyboard shortcuts',
                icon: Icons.keyboard_outlined,
                collapsible: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Example: Control+Shift+P. Leave a binding empty to disable it.',
                    ),
                    for (final row in playerActionTitles.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width: 260,
                              child: TextField(
                                controller: _local[row.key],
                                decoration: InputDecoration(
                                  labelText: row.value,
                                ),
                              ),
                            ),
                            if (Platform.isMacOS || Platform.isWindows)
                              SizedBox(
                                width: 260,
                                child: TextField(
                                  controller: _global[row.key],
                                  decoration: InputDecoration(
                                    labelText: '${row.value} · global',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        for (final action in playerActionTitles.keys) {
                          _local[action]!.text =
                              playerShortcutDefaults[action] ?? '';
                          _global[action]!.clear();
                        }
                      }),
                      child: const Text('Reset shortcuts'),
                    ),
                  ],
                ),
              ),
              StudySection(
                title: 'Mouse and modified seeks',
                icon: Icons.mouse_outlined,
                collapsible: true,
                child: Column(
                  children: [
                    for (final entry in {
                      'singleClick': 'Single click',
                      'doubleClick': 'Double click',
                      'verticalScroll': 'Vertical scroll',
                      'horizontalScroll': 'Horizontal scroll',
                    }.entries)
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          '${entry.key}:${_interactions[entry.key]}',
                        ),
                        initialValue: _interactions[entry.key] as String?,
                        decoration: InputDecoration(labelText: entry.value),
                        items: [
                          for (final action
                              in entry.key.contains('Click')
                                  ? ['none', 'playPause', 'fullscreen']
                                  : ['none', 'volume', 'seek'])
                            DropdownMenuItem(
                              value: action,
                              child: Text(
                                {
                                  'none': 'Nothing',
                                  'playPause': 'Play / pause',
                                  'fullscreen': 'Fullscreen',
                                  'volume': 'Volume',
                                  'seek': 'Seek',
                                }[action]!,
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _interactions[entry.key] = v),
                      ),
                    SwitchListTile(
                      title: const Text('Reverse scroll direction'),
                      value: _interactions['reverseScroll'] == true,
                      onChanged: (v) =>
                          setState(() => _interactions['reverseScroll'] = v),
                    ),
                    for (final entry in {
                      'veryShortSkip': 'Control + arrows · seconds',
                      'mediumSkip': 'Shift + arrows · seconds',
                      'longSkip': 'Alt + arrows · seconds',
                    }.entries)
                      TextFormField(
                        key: ValueKey(
                          '${entry.key}:${_interactions[entry.key]}',
                        ),
                        initialValue: '${_interactions[entry.key]}',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: entry.value),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) _interactions[entry.key] = n;
                        },
                      ),
                  ],
                ),
              ),
              FutureBuilder<String?>(
                future: ref
                    .read(appDatabaseProvider)
                    .getSetting('player.desktop.error'),
                builder: (context, snapshot) =>
                    snapshot.data?.isNotEmpty == true
                    ? Text(snapshot.data!)
                    : const SizedBox.shrink(),
              ),
              StudySection(
                title: 'Player behavior',
                description:
                    'Window/startup changes apply next time a player opens. Tray and track notification changes apply after Save.',
                icon: Icons.window_outlined,
                collapsible: true,
                child: Column(
                  children: [
                    for (final entry
                        in PlayerBehaviorPreferences.fields.entries)
                      if (DesktopPlaybackWindows.available ||
                          {
                            'repeat',
                            'shuffle',
                            'startPlaying',
                            'continue',
                            'stopEach',
                            'startFullscreen',
                            'preventSleep',
                            'rememberVolume',
                            'startupVolume',
                            'compactStartup',
                            'autoHide',
                            'hideAfter',
                            'controlsOpacity',
                            'fullscreenControls',
                            'coverArt',
                            'saveHistory',
                            'resume',
                            'historyExclusion',
                          }.contains(entry.key))
                        _field({
                          'key': entry.key,
                          ...entry.value,
                          'category': 'Player behavior',
                        }),
                  ],
                ),
              ),
              if (_fields.isNotEmpty) ...[
                const SizedBox(height: 16),
                StudySection(
                  title: 'Native engine preferences',
                  description: 'Decoder, track, network and output options.',
                  icon: Icons.tune,
                  collapsible: true,
                  child: Column(
                    children: [for (final field in _fields) _field(field)],
                  ),
                ),
              ],
            ],
          ),
  );
  Widget _field(Map field) {
    final key = field['key'] as String, type = field['type'] as String;
    final value = _native[key] ?? field['initial'] as String;
    if (type == 'toggle') {
      return SwitchListTile(
        title: Text(field['title'] as String),
        subtitle: Text(field['category'] as String),
        value: value == 'true',
        onChanged: (v) => setState(() => _native[key] = '$v'),
      );
    }
    if (type == 'choice') {
      final choices = (field['choices'] as List).cast<String>();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$key:$value'),
          initialValue: choices.contains(value) ? value : choices.first,
          decoration: InputDecoration(labelText: field['title'] as String),
          isExpanded: true,
          items: [
            for (final choice in choices)
              DropdownMenuItem(
                value: choice,
                child: Text(choice.isEmpty ? 'Automatic' : choice),
              ),
          ],
          onChanged: (v) => setState(() => _native[key] = v!),
        ),
      );
    }
    if (type == 'slider') {
      final min = (field['min'] as num).toDouble(),
          max = (field['max'] as num).toDouble();
      final number = (double.tryParse(value) ?? min).clamp(min, max);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${field['title']}: $number'),
          Slider(
            value: number,
            min: min,
            max: max,
            onChanged: (v) => setState(() => _native[key] = v.toString()),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        key: ValueKey('$key:$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: field['title'] as String),
        onChanged: (v) => _native[key] = v,
      ),
    );
  }
}
