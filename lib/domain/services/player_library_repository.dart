import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../data/db/app_database.dart';

enum QueueRepeat { off, all, one }

class QueueEntry {
  const QueueEntry(this.id, this.itemId);
  final String id;
  final String itemId;
  Map<String, Object?> toJson() => {'id': id, 'itemId': itemId};
}

class NamedMediaPlaylist {
  const NamedMediaPlaylist({
    required this.id,
    required this.title,
    required this.itemIds,
    this.artwork,
  });
  final String id;
  final String title;
  final List<String> itemIds;
  final String? artwork;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'itemIds': itemIds,
    if (artwork != null) 'artwork': artwork,
  };
}

class PlayerLibraryState {
  PlayerLibraryState({
    List<QueueEntry>? queue,
    List<String>? playOrder,
    List<NamedMediaPlaylist>? playlists,
    this.currentEntryId,
    this.shuffle = false,
    this.repeat = QueueRepeat.off,
    this.legacyQueueImported = false,
    List<String>? deletedPlaylistIds,
  }) : queue = queue ?? [],
       playOrder = playOrder ?? [],
       playlists = playlists ?? [],
       deletedPlaylistIds = deletedPlaylistIds ?? [];
  final List<QueueEntry> queue;
  final List<String> playOrder;
  final List<NamedMediaPlaylist> playlists;
  String? currentEntryId;
  bool shuffle;
  QueueRepeat repeat;
  bool legacyQueueImported;
  final List<String> deletedPlaylistIds;
  QueueEntry? get current =>
      queue.where((entry) => entry.id == currentEntryId).firstOrNull;
  Map<String, Object?> toJson() => {
    'queue': queue.map((e) => e.toJson()).toList(),
    'playOrder': playOrder,
    'playlists': playlists.map((e) => e.toJson()).toList(),
    'currentEntryId': currentEntryId,
    'shuffle': shuffle,
    'repeat': repeat.name,
    'legacyQueueImported': legacyQueueImported,
    'deletedPlaylistIds': deletedPlaylistIds,
  };
  static PlayerLibraryState fromJson(Map json) {
    final queue = (json['queue'] as List? ?? [])
        .map((row) => QueueEntry(row['id'] as String, row['itemId'] as String))
        .toList();
    final ids = queue.map((e) => e.id).toSet();
    final order = (json['playOrder'] as List? ?? [])
        .cast<String>()
        .where(ids.contains)
        .toList();
    for (final id in ids) {
      if (!order.contains(id)) order.add(id);
    }
    return PlayerLibraryState(
      queue: queue,
      playOrder: order,
      currentEntryId: json['currentEntryId'] as String?,
      shuffle: json['shuffle'] == true,
      repeat:
          QueueRepeat.values
              .where((v) => v.name == json['repeat'])
              .firstOrNull ??
          QueueRepeat.off,
      legacyQueueImported: json['legacyQueueImported'] == true,
      deletedPlaylistIds: (json['deletedPlaylistIds'] as List? ?? [])
          .cast<String>(),
      playlists: (json['playlists'] as List? ?? [])
          .map(
            (row) => NamedMediaPlaylist(
              id: row['id'] as String,
              title: row['title'] as String,
              itemIds: (row['itemIds'] as List).cast<String>(),
              artwork: row['artwork'] as String?,
            ),
          )
          .toList(),
    );
  }
}

class PlaylistImportPreview {
  const PlaylistImportPreview(this.title, this.itemIds, this.unmatched);
  final String title;
  final List<String> itemIds;
  final List<String> unmatched;
}

/// Local playback organization. Item IDs remain the sole history identity.
/// These non-secret settings participate in the existing backup transaction.
class PlayerLibraryRepository {
  const PlayerLibraryRepository(this.database, {this.queueNamespace});
  final String? queueNamespace;
  final AppDatabase database;
  static const settingKey = 'player.library.v1';

  Future<PlayerLibraryState> load() async {
    final raw = await database.getSetting(settingKey);
    final state = raw == null
        ? PlayerLibraryState()
        : PlayerLibraryState.fromJson(jsonDecode(raw) as Map);
    final legacy = await database.getSetting('myvlc.playlists');
    if (legacy != null) {
      for (final row in (jsonDecode(legacy) as Map).values) {
        final oldIndex = state.playlists.indexWhere((p) => p.id == row['id']);
        if (oldIndex >= 0 &&
            state.playlists[oldIndex].artwork == null &&
            row['artwork'] is String) {
          final old = state.playlists[oldIndex];
          state.playlists[oldIndex] = NamedMediaPlaylist(
            id: old.id,
            title: old.title,
            itemIds: old.itemIds,
            artwork: row['artwork'] as String,
          );
        }
        if (state.deletedPlaylistIds.contains(row['id']) ||
            state.playlists.any((value) => value.id == row['id'])) {
          continue;
        }
        state.playlists.add(
          NamedMediaPlaylist(
            id: row['id'] as String,
            title: row['title'] as String,
            itemIds: (row['itemIds'] as List).cast<String>(),
            artwork: row['artwork'] as String?,
          ),
        );
      }
    }
    if (!state.legacyQueueImported) {
      final legacyQueue = await database.getSetting('myvlc.queue');
      if (legacyQueue != null) {
        if (state.queue.isEmpty) {
          for (final row
              in (jsonDecode(legacyQueue) as List).cast<String>().indexed) {
            final entry = QueueEntry('legacy-queue-${row.$1}', row.$2);
            state.queue.add(entry);
            state.playOrder.add(entry.id);
          }
        }
        state.legacyQueueImported = true;
      }
    }
    if (queueNamespace != null) {
      final rawQueue = await database.getSetting(
        'player.window.queue:$queueNamespace',
      );
      final queue = rawQueue == null
          ? <String, dynamic>{
              'queue': [],
              'playOrder': [],
              'currentEntryId': null,
              'shuffle': false,
              'repeat': 'off',
            }
          : jsonDecode(rawQueue) as Map;
      return PlayerLibraryState.fromJson({
        ...state.toJson(),
        ...queue,
        'playlists': state.playlists.map((p) => p.toJson()).toList(),
        'deletedPlaylistIds': state.deletedPlaylistIds,
        'legacyQueueImported': true,
      });
    }
    return state;
  }

  Stream<PlayerLibraryState> watch() =>
      database.select(database.appSettings).watch().asyncMap((_) => load());
  Future<T> _update<T>(Future<T> Function(PlayerLibraryState) change) =>
      database.transaction(() async {
        // Acquire the WAL writer before reading a cross-engine queue snapshot.
        // busy_timeout can wait here; a deferred read-to-write upgrade cannot.
        await database.customStatement(
          'UPDATE app_settings SET value = value WHERE key = ?',
          [settingKey],
        );
        final state = await load();
        final result = await change(state);
        if (queueNamespace == null) {
          await database.setSetting(settingKey, jsonEncode(state.toJson()));
        } else {
          final raw = await database.getSetting(settingKey);
          final global = raw == null
              ? PlayerLibraryState().toJson()
              : Map<String, dynamic>.from(jsonDecode(raw) as Map);
          global['playlists'] = state.playlists.map((p) => p.toJson()).toList();
          global['deletedPlaylistIds'] = state.deletedPlaylistIds;
          await database.setSetting(settingKey, jsonEncode(global));
          final queue = Map<String, dynamic>.from(state.toJson())
            ..remove('playlists')
            ..remove('deletedPlaylistIds');
          await database.setSetting(
            'player.window.queue:$queueNamespace',
            jsonEncode(queue),
          );
        }
        return result;
      });

  Future<void> _validate(List<String> ids) async {
    if (ids.length > 10000) {
      throw const FormatException(
        'A queue or playlist can contain at most 10,000 entries.',
      );
    }
    for (final id in ids.toSet()) {
      final item = await database.getItemById(id);
      if (item == null || !['video', 'audio'].contains(item.itemType)) {
        throw const FormatException(
          'Playlists can contain existing audio and video items.',
        );
      }
    }
  }

  Future<String> savePlaylist(
    String title,
    List<String> ids, {
    String? playlistId,
  }) => _update((state) async {
    if (title.trim().isEmpty || title.length > 200) {
      throw const FormatException('Enter a playlist name of 1–200 characters.');
    }
    await _validate(ids);
    final id = playlistId ?? const Uuid().v4();
    final index = state.playlists.indexWhere((p) => p.id == id);
    final playlist = NamedMediaPlaylist(
      id: id,
      title: title.trim(),
      itemIds: List.of(ids),
      artwork: index < 0 ? null : state.playlists[index].artwork,
    );
    if (index < 0) {
      state.playlists.add(playlist);
    } else {
      state.playlists[index] = playlist;
    }
    return id;
  });
  Future<void> deletePlaylist(String id) => _update((state) async {
    state.playlists.removeWhere((value) => value.id == id);
    if (!state.deletedPlaylistIds.contains(id)) {
      state.deletedPlaylistIds.add(id);
    }
    // Keep a tombstone so the retained legacy import cannot resurrect it.
    final legacy = await database.getSetting('myvlc.playlists');
    if (legacy != null) {
      final rows = Map<String, dynamic>.from(jsonDecode(legacy) as Map)
        ..remove(id);
      await database.setSetting('myvlc.playlists', jsonEncode(rows));
    }
  });
  Future<void> setQueue(List<String> itemIds, {int currentIndex = 0}) =>
      _update((state) async {
        await _validate(itemIds);
        state.queue.clear();
        state.playOrder.clear();
        for (final id in itemIds) {
          final entry = QueueEntry(const Uuid().v4(), id);
          state.queue.add(entry);
          state.playOrder.add(entry.id);
        }
        state.currentEntryId = state.queue.isEmpty
            ? null
            : state.queue[currentIndex.clamp(0, state.queue.length - 1)].id;
        state.legacyQueueImported = true;
        if (state.shuffle) _shuffle(state, Random());
      });
  Future<void> enqueue(String itemId) => _update((state) async {
    await _validate([itemId]);
    if (state.queue.length >= 10000) {
      throw const FormatException('The queue is full.');
    }
    final entry = QueueEntry(const Uuid().v4(), itemId);
    state.queue.add(entry);
    state.playOrder.add(entry.id);
  });
  Future<void> select(String entryId) => _update((state) async {
    if (!state.queue.any((value) => value.id == entryId)) {
      throw StateError('Queue entry no longer exists.');
    }
    state.currentEntryId = entryId;
  });
  Future<void> remove(String entryId) => _update((state) async {
    state.queue.removeWhere((entry) => entry.id == entryId);
    state.playOrder.remove(entryId);
    // Removing the current row stops queue navigation, not the active media.
    if (state.currentEntryId == entryId) state.currentEntryId = null;
  });
  Future<void> reorder(int oldIndex, int newIndex) => _update((state) async {
    if (oldIndex < 0 ||
        oldIndex >= state.queue.length ||
        newIndex < 0 ||
        newIndex > state.queue.length) {
      return;
    }
    if (newIndex > oldIndex) newIndex--;
    state.queue.insert(newIndex, state.queue.removeAt(oldIndex));
    if (!state.shuffle) {
      state.playOrder
        ..clear()
        ..addAll(state.queue.map((e) => e.id));
    }
  });
  Future<void> setShuffle(bool enabled, {Random? random}) =>
      _update((state) async {
        state.shuffle = enabled;
        if (enabled) {
          _shuffle(state, random ?? Random());
        } else {
          state.playOrder
            ..clear()
            ..addAll(state.queue.map((e) => e.id));
        }
      });
  static void _shuffle(PlayerLibraryState state, Random random) {
    final remaining =
        state.queue
            .map((e) => e.id)
            .where((id) => id != state.currentEntryId)
            .toList()
          ..shuffle(random);
    state.playOrder
      ..clear()
      ..addAll([
        if (state.currentEntryId != null) state.currentEntryId!,
        ...remaining,
      ]);
  }

  Future<void> setRepeat(QueueRepeat repeat) => _update((state) async {
    state.repeat = repeat;
  });

  Future<String?> advance({
    required String currentItemId,
    bool forward = true,
    bool automatic = false,
  }) => _update((state) async {
    if (state.current?.itemId != currentItemId || state.playOrder.isEmpty) {
      return null;
    }
    if (automatic && state.repeat == QueueRepeat.one) return currentItemId;
    var index =
        state.playOrder.indexOf(state.currentEntryId!) + (forward ? 1 : -1);
    for (
      var visited = 0;
      visited < state.playOrder.length;
      visited++, index += forward ? 1 : -1
    ) {
      if (index < 0 || index >= state.playOrder.length) {
        if (state.repeat != QueueRepeat.all) return null;
        index = (index + state.playOrder.length) % state.playOrder.length;
      }
      final entry = state.queue.firstWhere(
        (e) => e.id == state.playOrder[index],
      );
      final item = await database.getItemById(entry.itemId);
      if (item != null &&
          !item.unavailable &&
          ['video', 'audio'].contains(item.itemType)) {
        state.currentEntryId = entry.id;
        return entry.itemId;
      }
    }
    return null;
  });

  Future<PlaylistImportPreview> previewPlaylist(File file) async {
    if (await file.length() > 2 * 1024 * 1024) {
      throw const FormatException('Playlist files are limited to 2 MiB.');
    }
    final text = (await file.readAsString()).replaceFirst(
      RegExp(r'^\uFEFF'),
      '',
    );
    final candidates = <String>[];
    if (p.extension(file.path).toLowerCase() == '.pls') {
      final rows = <int, String>{};
      for (final line in const LineSplitter().convert(text)) {
        final match = RegExp(
          r'^File(\d+)=(.*)$',
          caseSensitive: false,
        ).firstMatch(line.trim());
        if (match != null) rows[int.parse(match[1]!)] = match[2]!;
      }
      for (final key in rows.keys.toList()..sort()) {
        candidates.add(rows[key]!);
      }
    } else {
      candidates.addAll(
        const LineSplitter()
            .convert(text)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && !s.startsWith('#')),
      );
    }
    if (candidates.length > 10000) {
      throw const FormatException('Playlist has more than 10,000 entries.');
    }
    await _indexPlaylistPaths();
    final requested = <String, String?>{};
    for (final candidate in candidates) {
      final uri = p.isAbsolute(candidate) ? null : Uri.tryParse(candidate);
      if (uri != null && uri.hasScheme && uri.scheme != 'file') {
        requested[candidate] = null;
        continue;
      }
      try {
        requested[candidate] = p.normalize(
          uri?.scheme == 'file'
              ? uri!.toFilePath()
              : p.absolute(p.join(p.dirname(file.path), candidate)),
        );
      } on ArgumentError {
        requested[candidate] = null;
      } on UnsupportedError {
        requested[candidate] = null;
      }
    }
    final unique = requested.values.whereType<String>().toSet().toList();
    final paths = <String, String>{};
    for (var offset = 0; offset < unique.length; offset += 200) {
      final batch = unique.skip(offset).take(200).toList();
      final rows = await database
          .customSelect(
            "SELECT path,MIN(item_id) AS id,COUNT(*) AS matches FROM playlist_path_index WHERE path IN (${batch.map((_) => '?').join(',')}) GROUP BY path",
            variables: batch.map(d.Variable.new).toList(),
          )
          .get();
      for (final row in rows) {
        if (row.data['matches'] == 1)
          paths[row.data['path'] as String] = row.data['id'] as String;
      }
    }
    final ids = <String>[], unmatched = <String>[];
    for (final candidate in candidates) {
      final match = paths[requested[candidate]];
      if (match != null)
        ids.add(match);
      else
        unmatched.add(candidate);
    }
    return PlaylistImportPreview(
      p.basenameWithoutExtension(file.path),
      ids,
      unmatched,
    );
  }

  /// Persist normalized aliases once; migration and invalidated paths are
  /// processed in bounded keyset pages, including old noncanonical file paths.
  Future<void> _indexPlaylistPaths() async {
    await database.customStatement(
      'CREATE TABLE IF NOT EXISTS playlist_path_index(item_id TEXT PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,path TEXT NOT NULL)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_playlist_path ON playlist_path_index(path,item_id)',
    );
    await database.customStatement(
      """CREATE TRIGGER IF NOT EXISTS playlist_path_changed AFTER UPDATE OF file_path,item_type ON items
      WHEN OLD.file_path <> NEW.file_path OR OLD.item_type <> NEW.item_type
      BEGIN DELETE FROM playlist_path_index WHERE item_id=NEW.id; END""",
    );
    var after = '';
    while (true) {
      final rows = await database
          .customSelect(
            'SELECT i.id,i.file_path,i.item_type FROM items i LEFT JOIN playlist_path_index x ON x.item_id=i.id WHERE i.id>? AND x.item_id IS NULL ORDER BY i.id LIMIT 256',
            variables: [d.Variable(after)],
          )
          .get();
      if (rows.isEmpty) break;
      await database.transaction(() async {
        for (final row in rows) {
          // Re-read inside the transaction so a concurrent scan cannot index an
          // obsolete path after its invalidation trigger already ran.
          final item = await database.getItemById(row.data['id'] as String);
          if (item == null) continue;
          final path =
              p.isAbsolute(item.filePath) &&
                  ['audio', 'video'].contains(item.itemType)
              ? p.normalize(item.filePath)
              : '';
          await database.customStatement(
            'INSERT OR REPLACE INTO playlist_path_index(item_id,path) VALUES(?,?)',
            [item.id, path],
          );
        }
      });
      after = rows.last.data['id'] as String;
    }
  }

  Future<String> exportPls(NamedMediaPlaylist playlist) async {
    final lines = ['[playlist]', 'NumberOfEntries=${playlist.itemIds.length}'];
    for (final entry in playlist.itemIds.indexed) {
      final item = await database.getItemById(entry.$2);
      if (item == null || !p.isAbsolute(item.filePath))
        throw const FormatException(
          'Export requires local files; remote credentials are never exported.',
        );
      final n = entry.$1 + 1;
      lines.addAll([
        'File$n=${Uri.file(item.filePath)}',
        'Title$n=${(item.userTitle ?? item.title).replaceAll(RegExp(r'[\r\n]'), ' ')}',
        'Length$n=${item.durationSeconds?.round() ?? -1}',
      ]);
    }
    return '${[...lines, 'Version=2'].join('\n')}\n';
  }

  Future<String> exportM3u(NamedMediaPlaylist playlist) async {
    final lines = ['#EXTM3U'];
    for (final id in playlist.itemIds) {
      final item = await database.getItemById(id);
      if (item == null || !p.isAbsolute(item.filePath)) {
        throw const FormatException(
          'Export requires available local file paths; remote credentials are never exported.',
        );
      }
      lines.add(
        '#EXTINF:-1,${(item.userTitle ?? item.title).replaceAll(RegExp(r'[\r\n]'), ' ')}',
      );
      lines.add(Uri.file(item.filePath).toString());
    }
    return '${lines.join('\n')}\n';
  }
}
