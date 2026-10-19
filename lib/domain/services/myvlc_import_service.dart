import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/supported_extensions.dart';
import '../../core/utils/id_utils.dart';
import '../../data/db/app_database.dart';

enum MyVlcProgressConflict { keepTangerine, useMyVlc }

class MyVlcImportPreview {
  const MyVlcImportPreview._(
    this._snapshot,
    this.sourcePath,
    this.newItems,
    this.existingItems,
    this.progressConflicts,
    this.playlists,
    this.warnings,
  );
  final Map<String, dynamic> _snapshot;
  final String sourcePath;
  final int newItems;
  final int existingItems;
  final int progressConflicts;
  final int playlists;
  final List<String> warnings;
}

/// Imports the original Swift Codable library without touching its files.
/// A preview is immutable and imports are transactional and repeatable.
class MyVlcImportService {
  const MyVlcImportService(this.database);
  final AppDatabase database;
  static const libraryId = 'myvlc-import-library';
  static const sectionId = 'myvlc-import-items';

  Future<MyVlcImportPreview> preview(File source) async {
    if (await source.length() > 16 * 1024 * 1024) {
      throw const FormatException(
        'The MyVLC library exceeds the 16 MiB import limit.',
      );
    }
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['items'] is! List ||
        (decoded['items'] as List).length > 10000) {
      throw const FormatException(
        'Choose MyVLC’s library.json (up to 10,000 items).',
      );
    }
    final items = _rows(decoded, 'items');
    final playlists = _rows(decoded, 'playlists');
    final existing = await _existingByPath();
    var added = 0, linked = 0, conflicts = 0;
    final warnings = <String>[];
    final seen = <String>{};
    for (final row in items) {
      final path = _path(row['url']);
      if (path == null) {
        warnings.add('Skipped a stream or unsupported file.');
        continue;
      }
      if (!seen.add(path)) continue;
      if (!await File(path).exists()) {
        warnings.add(
          '${p.basename(path)} is missing or needs folder permission; its history will be retained.',
        );
      }
      _resume(row);
      final imported = await database.getItemById(
        stableId('myvlc:${Uri.file(path)}'),
      );
      final matches = existing[path] ?? (imported == null ? [] : [imported]);
      if (matches.length > 1) {
        warnings.add(
          'Multiple Tangerine items refer to ${p.basename(path)}; skipped for manual resolution.',
        );
        continue;
      }
      if (matches.isEmpty) {
        added++;
      } else {
        linked++;
        if (await database.getPlaybackByItemId(matches.single.id) != null) {
          conflicts++;
        }
      }
    }
    return MyVlcImportPreview._(
      decoded,
      source.path,
      added,
      linked,
      conflicts,
      playlists.length,
      List.unmodifiable(warnings),
    );
  }

  Future<int> import(
    MyVlcImportPreview preview, {
    MyVlcProgressConflict conflict = MyVlcProgressConflict.keepTangerine,
  }) => database.transaction(() async {
    final snapshot = preview._snapshot;
    final entries = _rows(snapshot, 'items');
    final existing =
        await _existingByPath(); // Resolve again inside the transaction.
    final mapping = <String, String>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    final device = await database.getDeviceId();
    var imported = 0;
    for (final row in entries) {
      final path = _path(row['url']);
      if (path == null) continue;
      final matches = existing[path] ?? [];
      if (matches.length > 1) continue;
      var item = matches.isEmpty
          ? await database.getItemById(stableId('myvlc:${Uri.file(path)}'))
          : matches.single;
      final uri = row['url'] as String;
      final id = item?.id ?? stableId('myvlc:${Uri.file(path)}');
      mapping[uri] = id;
      if (item == null) {
        if (await database.getLibraryById(libraryId) == null) {
          await database.upsertLibrary(
            LibrariesCompanion.insert(
              id: libraryId,
              title: 'MyVLC imports',
              rootFolderPath: 'import:myvlc',
              createdAt: now,
              updatedAt: now,
            ),
          );
          await database.upsertSection(
            SectionsCompanion.insert(
              id: sectionId,
              libraryId: libraryId,
              title: 'Media',
              orderIndex: 0,
              folderPath: 'import:myvlc',
            ),
          );
        }
        await database.upsertItem(
          ItemsCompanion.insert(
            id: id,
            libraryId: libraryId,
            sectionId: sectionId,
            title: p.basenameWithoutExtension(path),
            filename: p.basename(path),
            filePath: path,
            relativePath: path,
            itemType: inferItemType(path).name,
            orderIndex: imported,
            unavailable: Value(!await File(path).exists()),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        item = (await database.getItemById(id))!;
        existing[path] = [item];
        imported++;
      }
      final saved = await database.getPlaybackByItemId(id);
      final resume = _resume(row);
      final played = row['lastPlayed'];
      final eventAt = played is num && played.isFinite
          ? ((played.toDouble() + 978307200) * 1000).round().clamp(0, now)
          : 0;
      // Explicit conflict selection applies only to a newer legacy event. A repeat
      // import cannot overwrite progress written after the first import.
      if (saved == null ||
          (conflict == MyVlcProgressConflict.useMyVlc &&
              eventAt > saved.lastEventAt)) {
        await database.upsertPlayback(
          PlaybackProgressCompanion.insert(
            itemId: id,
            lastPositionSeconds: Value(resume),
            resumePositionSeconds: Value(resume),
            lastOpenedAt: Value(eventAt),
            lastEventAt: Value(eventAt),
            deviceId: device,
          ),
        );
      }
      final subtitle = _path(row['subtitleURL'], subtitle: true);
      if (subtitle != null &&
          await database.getSetting('subtitle.$id') == null) {
        await database.setSetting('subtitle.$id', subtitle);
      }
    }
    final previous = await database.getSetting('myvlc.playlists');
    final playlists = previous == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(previous) as Map);
    for (final row in _rows(snapshot, 'playlists')) {
      final legacyID = row['id'];
      final title = row['title'];
      final members = row['mediaIDs'];
      if (legacyID is! String ||
          title is! String ||
          members is! List ||
          members.any((v) => v is! String)) {
        throw const FormatException(
          'A MyVLC playlist is malformed. No data was imported.',
        );
      }
      playlists.putIfAbsent(
        legacyID,
        () => {
          'id': legacyID,
          'title': title,
          'itemIds': members
              .map((v) => mapping[v])
              .whereType<String>()
              .toList(),
        },
      );
    }
    await database.setSetting('myvlc.playlists', jsonEncode(playlists));
    final queue = snapshot['queue'];
    if (queue != null && (queue is! List || queue.any((v) => v is! String))) {
      throw const FormatException(
        'The MyVLC queue is malformed. No data was imported.',
      );
    }
    if (await database.getSetting('myvlc.queue') == null) {
      await database.setSetting(
        'myvlc.queue',
        jsonEncode(
          (queue as List? ?? [])
              .map((v) => mapping[v])
              .whereType<String>()
              .toList(),
        ),
      );
    }
    return imported;
  });

  Future<Map<String, List<Item>>> _existingByPath() async {
    final result = <String, List<Item>>{};
    for (final item in await database.select(database.items).get()) {
      if (p.isAbsolute(item.filePath)) {
        (result[p.normalize(item.filePath)] ??= []).add(item);
      }
    }
    return result;
  }

  static List<Map<String, dynamic>> _rows(
    Map<String, dynamic> data,
    String key,
  ) {
    final rows = data[key] ?? [];
    if (rows is! List ||
        rows.length > 10000 ||
        rows.any((r) => r is! Map<String, dynamic>)) {
      throw const FormatException(
        'The MyVLC library contains invalid records.',
      );
    }
    return rows.cast<Map<String, dynamic>>();
  }

  static String? _path(Object? value, {bool subtitle = false}) {
    if (value == null) return null;
    if (value is! String || value.contains('\u0000')) {
      throw const FormatException('Invalid MyVLC file URL.');
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'file' ||
        uri.host.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final path = p.normalize(uri.toFilePath());
    if (!p.isAbsolute(path)) return null;
    final ext = p.extension(path).toLowerCase();
    if (subtitle
        ? !['.srt', '.vtt', '.ass', '.ssa'].contains(ext)
        : ![ItemType.audio, ItemType.video].contains(inferItemType(path))) {
      return null;
    }
    return path;
  }

  static double _resume(Map<String, dynamic> row) {
    final value = row['resumeTime'] ?? 0;
    if (value is! num || !value.isFinite || value < 0) {
      throw const FormatException('Invalid MyVLC resume position.');
    }
    return value.toDouble() /
        1000; // The original Swift engine stores milliseconds.
  }
}
