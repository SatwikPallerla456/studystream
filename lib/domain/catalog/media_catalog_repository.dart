import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../data/db/app_database.dart';
import '../../data/indexer/library_source_store.dart';
import 'media_record_contract.dart';
import 'catalog_identity_store.dart';

enum LibraryKind {
  mixed('Mixed'),
  movies('Movies'),
  television('TV Shows'),
  music('Music'),
  musicVideos('Music Videos'),
  homeVideos('Home Videos'),
  photos('Photos'),
  audiobooks('Audiobooks'),
  podcasts('Podcasts'),
  books('Books'),
  comics('Comics & Manga'),
  documents('Documents'),
  courses('Courses');

  const LibraryKind(this.label);
  final String label;
}

class LibrarySource {
  LibrarySource(Map<String, dynamic> row)
    : id = row['id'] as String,
      libraryId = row['library_id'] as String,
      root = row['root_path'] as String,
      namespace = row['namespace'] as String,
      unavailable = row['unavailable'] == 1;
  final String id, libraryId, root, namespace;
  final bool unavailable;
}

class MediaRecord {
  MediaRecord(Map<String, dynamic> row)
    : id = row['id'] as String,
      kind = row['kind'] as String,
      libraryId = row['library_id'] as String,
      itemId = row['item_id'] as String?,
      data = Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String) as Map,
      ),
      updatedAt = row['updated_at'] as int,
      deleted = row['deleted'] == 1;
  final String id, kind, libraryId;
  final String? itemId;
  final Map<String, dynamic> data;
  final int updatedAt;
  final bool deleted;
}

/// Local/manual catalog works offline. File history always belongs to Items.
class MediaCatalogRepository {
  MediaCatalogRepository(this.db);
  final AppDatabase db;
  Future<List<MediaRecord>> records(String libraryId, {String? kind}) async =>
      (await db
              .customSelect(
                'SELECT * FROM media_records WHERE library_id = ? AND deleted = 0${kind == null ? '' : ' AND kind = ?'} ORDER BY updated_at DESC',
                variables: [
                  Variable(libraryId),
                  if (kind != null) Variable(kind),
                ],
              )
              .get())
          .map((r) => MediaRecord(r.data))
          .toList();
  Future<MediaRecord?> record(String id) async {
    final row = await db
        .customSelect(
          'SELECT * FROM media_records WHERE id = ? AND deleted = 0',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    return row == null ? null : MediaRecord(row.data);
  }

  Future<LibraryKind> libraryKind(String libraryId) async {
    final data = (await record('library:$libraryId'))?.data;
    return LibraryKind.values.firstWhere(
      (k) => k.name == data?['type'],
      orElse: () => LibraryKind.mixed,
    );
  }

  Future<void> save(
    String id,
    String kind,
    String libraryId,
    Map<String, dynamic> data, {
    String? itemId,
    bool deleted = false,
  }) async {
    MediaRecordContract.validate(
      id: id,
      kind: kind,
      libraryId: libraryId,
      itemId: itemId,
      data: data,
    );
    await db.transaction(() async {
      if (await db.getLibraryById(libraryId) == null) {
        throw const FormatException('Library no longer exists');
      }
      if (itemId != null &&
          (await db.getItemById(itemId))?.libraryId != libraryId) {
        throw const FormatException('Item is outside this library');
      }
      final existing = await db
          .customSelect(
            'SELECT updated_at FROM media_records WHERE id = ?',
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      final previous = existing?.data['updated_at'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.importMediaRows({
        'mediaRecords': [
          {
            'id': id,
            'kind': kind,
            'library_id': libraryId,
            'item_id': itemId,
            'payload': jsonEncode(data),
            'updated_at': now > previous ? now : previous + 1,
            'device_id': await db.getDeviceId(),
            'deleted': deleted ? 1 : 0,
          },
        ],
      });
    });
  }

  Future<void> setLibraryKind(String libraryId, LibraryKind kind) async {
    final old = (await record('library:$libraryId'))?.data ?? {};
    await save('library:$libraryId', 'library', libraryId, {
      ...old,
      'type': kind.name,
    });
  }

  Future<List<LibrarySource>> sources(String libraryId) async {
    final library = await db.getLibraryById(libraryId);
    if (library != null &&
        !library.rootFolderPath.startsWith('remote:') &&
        !library.rootFolderPath.startsWith('import:')) {
      await db.customStatement(
        'INSERT OR IGNORE INTO library_sources(id,library_id,root_path,namespace,updated_at) VALUES(?,?,?,?,?)',
        [
          'legacy:$libraryId',
          libraryId,
          library.rootFolderPath,
          '',
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
    }
    return (await db
            .customSelect(
              'SELECT * FROM library_sources WHERE library_id = ? ORDER BY namespace',
              variables: [Variable(libraryId)],
            )
            .get())
        .map((r) => LibrarySource(r.data))
        .toList();
  }

  Future<LibrarySource> addSource(String libraryId, String root) async {
    final normalized = p.normalize(p.absolute(root));
    for (final source in await sources(libraryId)) {
      if (p.equals(source.root, normalized) ||
          p.isWithin(source.root, normalized) ||
          p.isWithin(normalized, source.root)) {
        throw const FormatException(
          'This folder overlaps an existing source. Select a separate folder to avoid duplicate files.',
        );
      }
    }
    final id = const Uuid().v4();
    await db.customStatement(
      'INSERT INTO library_sources(id,library_id,root_path,namespace,updated_at) VALUES(?,?,?,?,?)',
      [
        id,
        libraryId,
        normalized,
        '@sources/$id',
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    return (await sources(libraryId)).firstWhere((s) => s.id == id);
  }

  Future<void> relinkSource(LibrarySource source, String root) async {
    final normalized = p.normalize(p.absolute(root));
    for (final other in await sources(source.libraryId)) {
      if (other.id != source.id &&
          (p.equals(other.root, normalized) ||
              p.isWithin(other.root, normalized) ||
              p.isWithin(normalized, other.root))) {
        throw const FormatException('Source folders must not overlap');
      }
    }
    await db.transaction(() async {
      await LibrarySourceStore(db).backfill();
      final assets=await db.customSelect('SELECT * FROM item_assets WHERE source_id = ?',variables:[Variable(source.id)]).get();
      for(final asset in assets) {
        final path=p.normalize(p.join(normalized,asset.data['relative_path'] as String));
        if(!p.isWithin(normalized,path)) throw const FormatException('Asset is outside the relinked source');
        await db.customStatement('UPDATE items SET file_path = ? WHERE id = ? AND library_id = ?', [path,asset.data['item_id'],source.libraryId]);
      }
      await db.customStatement('UPDATE library_sources SET root_path = ?, unavailable = 0, updated_at = ? WHERE id = ?',
        [normalized,DateTime.now().millisecondsSinceEpoch,source.id]);
      if(source.namespace.isEmpty) await db.customStatement('UPDATE libraries SET root_folder_path = ? WHERE id = ?', [normalized,source.libraryId]);
      db.notifyUpdates({TableUpdate.onTable(db.items),TableUpdate.onTable(db.libraries)});
    });
  }

  Future<void> setSourceAvailability(
    LibrarySource source,
    bool unavailable,
  ) => db.customStatement(
    'UPDATE library_sources SET unavailable = ?, updated_at = ? WHERE id = ?',
    [unavailable ? 1 : 0, DateTime.now().millisecondsSinceEpoch, source.id],
  );
  Future<Map<String,dynamic>> metadata(Item item) async => CatalogIdentityStore(db).resolve(item,(await record('metadata:${item.id}'))?.data??{});
  Future<void> saveMetadata(Item item,Map<String,dynamic> data) => db.transaction(()async{
    final store=CatalogIdentityStore(db);
    for(final entry in data.entries) {
      if(MediaRecordContract.fields('metadata')!.contains(entry.key) && !['matchState','source','providerId','providerItemId'].contains(entry.key)) {
        await store.override(item,entry.key,entry.value,remove:entry.value==null);
      }
    }
  });
  Future<void> setFavorite(Item item, bool value) async {
    final old = (await record('organization:${item.id}'))?.data ?? {};
    await save('organization:${item.id}', 'organization', item.libraryId, {
      ...old,
      'favorite': value,
    }, itemId: item.id);
  }

  Future<void> setTags(Item item, List<String> tags) async {
    final old = (await record('organization:${item.id}'))?.data ?? {};
    await save('organization:${item.id}', 'organization', item.libraryId, {
      ...old,
      'tags': tags
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toSet()
          .take(100)
          .toList(),
    }, itemId: item.id);
  }

  Future<void> saveCollection(
    String libraryId,
    String title,
    List<String> itemIds, {
    String? id,
    String type = 'collection',
  }) async {
    final valid = <String>[];
    for (final id in itemIds.toSet()) {
      if ((await db.getItemById(id))?.libraryId == libraryId) valid.add(id);
    }
    await save(id ?? const Uuid().v4(), type, libraryId, {
      'title': title.trim(),
      'items': valid,
    });
  }

  static Map<String,dynamic> parseFilename(String filename) => CatalogIdentityStore.filenameHints(filename);
}
