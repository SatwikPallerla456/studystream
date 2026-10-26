import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;

import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/services/player_library_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/study_ui.dart';

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key, this.currentItemId});
  final String? currentItemId;
  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  String? _selected;
  String _search = '';
  bool _busy = false, _tree = false;
  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }

  Future<void> _loadViewPreference() async {
    final raw = await ref
        .read(appDatabaseProvider)
        .getSetting('player.native.preferences');
    if (raw == null) return;
    final value = jsonDecode(raw) as Map;
    if (mounted) setState(() => _tree = value['playlistTree'] == 'true');
  }

  Future<void> _setTree(bool value) async {
    setState(() => _tree = value);
    final db = ref.read(appDatabaseProvider);
    await db.transaction(() async {
      final prefs = Map<String, dynamic>.from(
        jsonDecode(await db.getSetting('player.native.preferences') ?? '{}')
            as Map,
      );
      prefs['playlistTree'] = '$value';
      await db.setSetting('player.native.preferences', jsonEncode(prefs));
    });
  }

  PlayerLibraryRepository get repository =>
      ref.read(playerLibraryRepositoryProvider);
  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message(
          error is FormatException
              ? error.message
              : 'The playlist change could not be saved.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _name(String initial) async {
    var title = initial;
    final result = await showStudyAdaptiveModal<String>(
      context: context,
      builder: (context) => StudyModalFrame(
        title: initial.isEmpty ? 'New playlist' : 'Rename playlist',
        primaryAction: FilledButton(
          onPressed: () {
            if (title.trim().isNotEmpty) Navigator.pop(context, title.trim());
          },
          child: const Text('Save'),
        ),
        child: TextFormField(
          initialValue: initial,
          onChanged: (value) => title = value,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Playlist name'),
          onFieldSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
      ),
    );
    // Adaptive modals may animate out after the returned future completes.
    return result;
  }

  Future<void> _import() => _run(() async {
    final files = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'pls'],
    );
    final path = files?.files.single.path;
    if (path == null) return;
    final preview = await repository.previewPlaylist(File(path));
    if (!mounted) return;
    final accepted = await showStudyAdaptiveModal<bool>(
      context: context,
      builder: (context) => StudyConfirmDialog(
        title: 'Import ${preview.title}?',
        message:
            '${preview.itemIds.length} existing audio/video entries found. ${preview.unmatched.length} entries are unresolved or remote and will be skipped. Import missing files into a library first, then retry.',
        confirmLabel: 'Import playlist',
      ),
    );
    if (accepted != true) return;
    final id = await repository.savePlaylist(preview.title, preview.itemIds);
    if (mounted) setState(() => _selected = id);
  });
  Future<void> _export(NamedMediaPlaylist playlist) => _run(() async {
    final format = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export playlist'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'm3u8'),
            child: const Text('M3U8 · UTF-8 playlist'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'pls'),
            child: const Text('PLS · numbered playlist'),
          ),
        ],
      ),
    );
    if (format == null) return;
    final text = format == 'pls'
        ? await repository.exportPls(playlist)
        : await repository.exportM3u(playlist);
    final bytes = Uint8List.fromList(utf8.encode(text));
    final selected = await FilePicker.platform.saveFile(
      dialogTitle: 'Export playlist',
      fileName: '${playlist.title.replaceAll(RegExp(r'[^\w -]'), '_')}.$format',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: [format],
    );
    if (selected != null && !Platform.isAndroid && !Platform.isIOS) {
      await File(selected).writeAsBytes(bytes, flush: true);
    }
  });
  void _open(String id) {
    if (widget.currentItemId != null) {
      Navigator.pop(context, id);
    } else {
      context.push('/player/$id?queue=1');
    }
  }

  Future<void> _chooseMedia(
    List<String> initial,
    ValueChanged<List<String>> done,
  ) async {
    final chosen = List<String>.of(initial);
    var query = '';
    await showStudyAdaptiveModal<void>(
      context: context,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, update) => StudyModalFrame(
          title: 'Add audio or video',
          primaryAction: FilledButton(
            onPressed: () {
              done(chosen);
              Navigator.pop(modalContext);
            },
            child: const Text('Done'),
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .55,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search library',
                  ),
                  onChanged: (value) => update(() => query = value),
                ),
                Expanded(
                  child: FutureBuilder<List<Item>>(
                    future: _media(query),
                    builder: (context, snapshot) => ListView(
                      children: [
                        for (final item in snapshot.data ?? <Item>[])
                          CheckboxListTile(
                            value: chosen.contains(item.id),
                            title: Text(item.userTitle ?? item.title),
                            subtitle: Text(item.filename),
                            onChanged: (value) => update(() {
                              if (value == true) {
                                chosen.add(item.id);
                              } else {
                                chosen.removeWhere((id) => id == item.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addMedia(List<String> ids, NamedMediaPlaylist? playlist) {
    _chooseMedia(
      ids,
      (chosen) => _run(() async {
        if (playlist == null) {
          for (final id in chosen.where((id) => !ids.contains(id))) {
            await repository.enqueue(id);
          }
        } else {
          await repository.savePlaylist(
            playlist.title,
            chosen,
            playlistId: playlist.id,
          );
        }
      }),
    );
  }

  Future<List<Item>> _media(String query) async {
    final db = ref.read(appDatabaseProvider);
    return (db.select(db.items)
          ..where(
            (t) =>
                t.itemType.isIn(['audio', 'video']) &
                (t.title.contains(query) |
                    t.userTitle.contains(query) |
                    t.filename.contains(query)),
          )
          ..limit(100))
        .get();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(playerLibraryStateProvider);
    return Scaffold(
      appBar: AppTopBar(
        title: 'Queue & playlists',
        showBack: true,
        actions: [
          IconButton(
            tooltip: 'Import M3U or PLS',
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            tooltip: 'New playlist',
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final title = await _name('');
                    if (title == null) return;
                    final id = await repository.savePlaylist(title, []);
                    if (mounted) setState(() => _selected = id);
                  }),
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Your playback lists could not be loaded.'),
        ),
        data: (state) {
          final playlist = state.playlists
              .where((p) => p.id == _selected)
              .firstOrNull;
          final ids =
              playlist?.itemIds ?? state.queue.map((e) => e.itemId).toList();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String?>(
                  value: playlist?.id,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Play queue'),
                    ),
                    for (final row in state.playlists)
                      DropdownMenuItem<String?>(
                        value: row.id,
                        child: Text(row.title),
                      ),
                  ],
                  onChanged: (value) => setState(() => _selected = value),
                ),
                if (ids.isNotEmpty || playlist != null)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      if (playlist == null && ids.isNotEmpty) ...[
                        FilterChip(
                          label: const Text('Shuffle'),
                          selected: state.shuffle,
                          onSelected: (value) =>
                              _run(() => repository.setShuffle(value)),
                        ),
                        SizedBox(
                          width: 240,
                          child: DropdownButton<QueueRepeat>(
                            isExpanded: true,
                            value: state.repeat,
                            items: [
                              for (final value in QueueRepeat.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text('Repeat: ${value.name}'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _run(() => repository.setRepeat(value));
                              }
                            },
                          ),
                        ),
                        TextButton(
                          onPressed: () => _run(() async {
                            final title = await _name('');
                            if (title != null) {
                              await repository.savePlaylist(title, ids);
                            }
                          }),
                          child: const Text('Save as playlist'),
                        ),
                      ] else if (playlist != null) ...[
                        FilledButton.icon(
                          onPressed: ids.isEmpty
                              ? null
                              : () => _run(() async {
                                  await repository.setQueue(ids);
                                  if (mounted) _open(ids.first);
                                }),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play'),
                        ),
                        TextButton(
                          onPressed: () => _run(() async {
                            final title = await _name(playlist.title);
                            if (title != null) {
                              await repository.savePlaylist(
                                title,
                                ids,
                                playlistId: playlist.id,
                              );
                            }
                          }),
                          child: const Text('Rename'),
                        ),
                        if (playlist.artwork != null)
                          _PlaylistArtwork(encoded: playlist.artwork!),
                        TextButton(
                          onPressed: () => _export(playlist),
                          child: const Text('Export'),
                        ),
                        TextButton(
                          onPressed: () => _run(() async {
                            final confirmed = await showStudyAdaptiveModal<bool>(
                              context: context,
                              builder: (context) => const StudyConfirmDialog(
                                title: 'Delete playlist?',
                                message:
                                    'Only this playlist is removed. Media and progress stay in your libraries.',
                                confirmLabel: 'Delete',
                                destructive: true,
                              ),
                            );
                            if (confirmed == true) {
                              await repository.deletePlaylist(playlist.id);
                              if (mounted) setState(() => _selected = null);
                            }
                          }),
                          child: const Text('Delete'),
                        ),
                      ],
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add media'),
                        onPressed: _busy
                            ? null
                            : () => _addMedia(ids, playlist),
                      ),
                    ],
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (ids.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Group by folder'),
                      selected: _tree,
                      onSelected: (value) => _run(() => _setTree(value)),
                    ),
                  ),
                if (_tree && ids.isNotEmpty)
                  const Text(
                    'Folder grouping preserves playback order. Turn it off to reorder entries.',
                  ),
                if (ids.isNotEmpty)
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Filter entries',
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                Expanded(
                  child: FutureBuilder<List<Item?>>(
                    future: Future.wait(
                      ids.map(
                        (id) => ref.read(appDatabaseProvider).getItemById(id),
                      ),
                    ),
                    builder: (context, snapshot) {
                      final items = snapshot.data;
                      if (items == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                playlist == null
                                    ? 'Your queue is empty'
                                    : 'This playlist is empty',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Choose audio or video from your libraries.',
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _addMedia(ids, playlist),
                                icon: const Icon(Icons.add),
                                label: const Text('Add media'),
                              ),
                            ],
                          ),
                        );
                      }
                      Widget entryTile(int index) {
                        final item = items[index];
                        final title =
                            item?.userTitle ?? item?.title ?? 'Removed media';
                        if (_search.isNotEmpty &&
                            !title.toLowerCase().contains(
                              _search.toLowerCase(),
                            )) {
                          return SizedBox.shrink(
                            key: ValueKey('hidden-$index'),
                          );
                        }
                        final entry = playlist == null
                            ? state.queue[index]
                            : null;
                        return ListTile(
                          key: ValueKey(entry?.id ?? '$index-${ids[index]}'),
                          selected:
                              entry != null && entry.id == state.currentEntryId,
                          leading: Icon(
                            item?.unavailable == true || item == null
                                ? Icons.link_off
                                : Icons.play_circle_outline,
                          ),
                          title: Text(title),
                          subtitle: Text(
                            item?.filename ?? 'Your saved entry is retained.',
                          ),
                          onTap: item == null || item.unavailable
                              ? null
                              : () => _run(() async {
                                  if (entry != null) {
                                    await repository.select(entry.id);
                                  } else {
                                    await repository.setQueue(
                                      ids,
                                      currentIndex: index,
                                    );
                                  }
                                  if (mounted) _open(ids[index]);
                                }),
                          trailing: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: IconButton(
                              tooltip: 'Remove entry',
                              icon: const Icon(Icons.close),
                              onPressed: () => _run(() async {
                                if (entry != null) {
                                  await repository.remove(entry.id);
                                } else {
                                  final updated = List.of(ids)..removeAt(index);
                                  await repository.savePlaylist(
                                    playlist!.title,
                                    updated,
                                    playlistId: playlist.id,
                                  );
                                }
                              }),
                            ),
                          ),
                        );
                      }

                      if (_tree) {
                        final folders = <String, List<int>>{};
                        for (var index = 0; index < items.length; index++) {
                          final item = items[index];
                          final title =
                              item?.userTitle ?? item?.title ?? 'Removed media';
                          if (_search.isNotEmpty &&
                              !title.toLowerCase().contains(
                                _search.toLowerCase(),
                              ))
                            continue;
                          final folder = item == null
                              ? 'Removed media'
                              : item.filePath.startsWith('remote:')
                              ? 'Remote library'
                              : path.dirname(item.filePath);
                          (folders[folder] ??= []).add(index);
                        }
                        return ListView(
                          children: [
                            for (final group in folders.entries)
                              ExpansionTile(
                                key: ValueKey('folder:${group.key}'),
                                leading: const Icon(Icons.folder_outlined),
                                title: Text(
                                  group.key == 'Remote library' ||
                                          group.key == 'Removed media'
                                      ? group.key
                                      : path.basename(group.key),
                                ),
                                subtitle: Text('${group.value.length} entries'),
                                children: [
                                  for (final index in group.value)
                                    entryTile(index),
                                ],
                              ),
                          ],
                        );
                      }
                      return ReorderableListView.builder(
                        buildDefaultDragHandles: _search.isEmpty,
                        itemCount: items.length,
                        onReorderItem: (old, next) => _run(() async {
                          if (_search.isNotEmpty) return;
                          if (playlist == null) {
                            await repository.reorder(
                              old,
                              next > old ? next + 1 : next,
                            );
                          } else {
                            final reordered = List.of(ids);
                            reordered.insert(next, reordered.removeAt(old));
                            await repository.savePlaylist(
                              playlist.title,
                              reordered,
                              playlistId: playlist.id,
                            );
                          }
                        }),
                        itemBuilder: (context, index) => entryTile(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlaylistArtwork extends StatelessWidget {
  const _PlaylistArtwork({required this.encoded});
  final String encoded;
  @override
  Widget build(BuildContext context) {
    if (encoded.length > 1400000) return const SizedBox.shrink();
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(encoded),
          width: 64,
          height: 64,
          cacheWidth: 128,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.queue_music),
        ),
      );
    } catch (_) {
      return const Icon(Icons.queue_music);
    }
  }
}
