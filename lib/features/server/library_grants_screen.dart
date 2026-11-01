import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import '../../data/db/app_database.dart';
import '../../data/sync/library_access_store.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/study_ui.dart';
import '../../shared/widgets/tangerine_controls.dart';

class LibraryGrantsScreen extends StatefulWidget {
  const LibraryGrantsScreen({
    super.key,
    required this.database,
    required this.device,
  });
  final AppDatabase database;
  final KnownDevice device;
  @override
  State<LibraryGrantsScreen> createState() => _LibraryGrantsState();
}

class _LibraryGrantsState extends State<LibraryGrantsScreen> {
  List<Library>? _libraries;
  final _grants = <String, Map<String, bool>>{};
  String? _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (mounted)
        setState(() {
          _error = null;
          _libraries = null;
        });
      final libraries = await widget.database
          .select(widget.database.libraries)
          .get();
      final rows = await widget.database
          .customSelect(
            'SELECT * FROM device_library_grants WHERE device_id=?',
            variables: [Variable(widget.device.id)],
          )
          .get();
      for (final row in rows) {
        _grants[row.data['library_id'] as String] = {
          for (final key in LibraryAccessStore.permissions)
            key: row.data[key] == 1,
        };
      }
      if (mounted)
        setState(
          () => _libraries = libraries
              .where(
                (lib) =>
                    !lib.rootFolderPath.startsWith('remote:') &&
                    !lib.rootFolderPath.startsWith('import:'),
              )
              .toList(),
        );
    } catch (_) {
      if (mounted)
        setState(() {
          _libraries = [];
          _error =
              'Library access could not load. Try again before changing permissions.';
        });
    }
  }

  Future<void> _set(String id, String key, bool value) async {
    if (_saving) return;
    final next = {...?_grants[id], key: value};
    setState(() => _saving = true);
    try {
      await LibraryAccessStore(widget.database).set(
        widget.device.id,
        id,
        browse: next['browse'] == true,
        stream: next['stream'] == true,
        mutate: next['mutate'] == true,
      );
      if (next['browse'] != true) {
        next['stream'] = false;
        next['mutate'] = false;
      }
      if (mounted) setState(() => _grants[id] = next);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = 'This permission could not be saved. Try again.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: 'Access for ${widget.device.name}',
      showBack: true,
    ),
    body: _libraries == null
        ? const Center(child: CircularProgressIndicator())
        : StudyPage(
            maxWidth: 880,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose what this player can access. New libraries require approval. Turning browsing off also turns off streaming and changes.',
                ),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: _saving ? null : _load,
                    child: const Text('Reload access'),
                  ),
                ],
                if (_libraries!.isEmpty && _error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No shareable folder libraries. Add a linked folder on the server to choose access here. Individually imported files and remote libraries are not shared by this host.',
                    ),
                  ),
                for (final library in _libraries!)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TangerinePreferenceSection(
                      key: ValueKey(library.id),
                      title: library.title,
                      icon: Icons.video_library_outlined,
                      collapsible: true,
                      description: _grants[library.id]?['browse'] == true
                          ? [
                              'Browsing',
                              if (_grants[library.id]?['stream'] == true)
                                'Streaming',
                              if (_grants[library.id]?['mutate'] == true)
                                'Sync & control',
                            ].join(' · ')
                          : 'No access · expand to choose permissions',
                      child: Column(
                        children: [
                          for (final permission
                              in LibraryAccessStore.permissions)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(switch (permission) {
                                'browse' => 'Browse catalog',
                                'stream' => 'Stream files',
                                _ => 'Sync changes and control playback',
                              }),
                              subtitle: permission == 'mutate'
                                  ? const Text(
                                      'Allow notes, bookmarks, progress and host playback commands.',
                                    )
                                  : null,
                              value: _grants[library.id]?[permission] ?? false,
                              onChanged:
                                  _saving ||
                                      permission != 'browse' &&
                                          _grants[library.id]?['browse'] != true
                                  ? null
                                  : (value) =>
                                        _set(library.id, permission, value),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}
