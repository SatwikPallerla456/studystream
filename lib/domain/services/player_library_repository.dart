import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
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
  });
  final String id;
  final String title;
  final List<String> itemIds;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'itemIds': itemIds,
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
  const PlayerLibraryRepository(this.database);
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
        if (state.deletedPlaylistIds.contains(row['id']) ||
            state.playlists.any((value) => value.id == row['id'])) {
          continue;
        }
        state.playlists.add(
          NamedMediaPlaylist(
            id: row['id'] as String,
            title: row['title'] as String,
            itemIds: (row['itemIds'] as List).cast<String>(),
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
    return state;
  }

  Stream<PlayerLibraryState> watch() =>
      database.select(database.appSettings).watch().asyncMap((_) => load());
  Future<T> _update<T>(Future<T> Function(PlayerLibraryState) change) =>
      database.transaction(() async {
        final state = await load();
        final result = await change(state);
        await database.setSetting(settingKey, jsonEncode(state.toJson()));
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
    final paths = <String, List<Item>>{};
    for (final item in await database.select(database.items).get()) {
      if (p.isAbsolute(item.filePath) &&
          ['audio', 'video'].contains(item.itemType)) {
        (paths[p.normalize(item.filePath)] ??= []).add(item);
      }
    }
    final ids = <String>[], unmatched = <String>[];
    for (final candidate in candidates) {
      final uri = p.isAbsolute(candidate) ? null : Uri.tryParse(candidate);
      if (uri != null && uri.hasScheme && uri.scheme != 'file') {
        unmatched.add(candidate);
        continue;
      }
      final path = p.normalize(
        uri?.scheme == 'file'
            ? uri!.toFilePath()
            : p.absolute(p.join(p.dirname(file.path), candidate)),
      );
      final matches = paths[path];
      if (matches?.length == 1) {
        ids.add(matches!.single.id);
      } else {
        unmatched.add(candidate);
      }
    }
    return PlaylistImportPreview(
      p.basenameWithoutExtension(file.path),
      ids,
      unmatched,
    );
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
