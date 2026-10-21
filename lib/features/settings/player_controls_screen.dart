import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/app_providers.dart';
import '../../domain/services/player_controls_repository.dart';
import '../../domain/services/player_profile_repository.dart';
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

  Future<void> _load() async {
    final repository = PlayerControlsRepository(ref.read(appDatabaseProvider));
    final controls = await repository.load();
    final native = await repository.nativePreferences();
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
      _fields = fields;
      _skip = controls.skipSeconds;
      _step = controls.volumeStep;
      _profiles = profiles;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = ref.read(appDatabaseProvider);
      await db.transaction(() async {
        await PlayerControlsRepository(db).save(
          PlayerControls(
            local: _local.map((k, c) => MapEntry(k, c.text)),
            global: _global.map((k, c) => MapEntry(k, c.text)),
            skipSeconds: _skip,
            volumeStep: _step,
          ),
        );
        await db.setSetting('player.native.preferences', jsonEncode(_native));
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
      final data = await const MethodChannel(
        'tangerine/playback',
      ).invokeMapMethod<String, dynamic>('preferences.importPreview');
      if (data == null || !mounted) return;
      final native = Map<String, String>.from(data['preferences'] as Map);
      final local = Map<String, String>.from(data['local'] as Map),
          global = Map<String, String>.from(data['global'] as Map);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import supported MyVLC settings?'),
          content: Text(
            '${native.length} engine preferences from ${data['source']}. Supported shortcuts will be staged for review. Credentials, account settings, source files and pairing settings stay unchanged. Press Save on the controls page to apply.',
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
        for (final action in playerActionTitles.keys) {
          if (local.containsKey(action)) _local[action]!.text = local[action]!;
          if (global.containsKey(action)) {
            _global[action]!.text = global[action]!;
          }
        }
        final speed = double.tryParse(data['speed'] as String? ?? '');
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
        await PlayerControlsRepository(db).save(
          PlayerControls(
            local: _local.map((k, c) => MapEntry(k, c.text)),
            global: _global.map((k, c) => MapEntry(k, c.text)),
            skipSeconds: _skip,
            volumeStep: _step,
          ),
        );
        await db.setSetting('player.native.preferences', jsonEncode(_native));
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
                  if (Platform.isMacOS)
                    OutlinedButton(
                      onPressed: _importPreferences,
                      child: const Text('Import MyVLC preferences'),
                    ),
                ],
              ),
              for (final profile in _profiles)
                ListTile(
                  title: Text(profile['title'] as String),
                  onTap: () async {
                    await PlayerProfileRepository(
                      ref.read(appDatabaseProvider),
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
                            if (Platform.isMacOS)
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
