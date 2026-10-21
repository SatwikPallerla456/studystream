import 'dart:convert';
import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import '../../core/utils/id_utils.dart';
import 'media_catalog_repository.dart';

class CatalogPart {
  const CatalogPart({
    required this.item,
    required this.duration,
    required this.offset,
  });
  final Item item;
  final double duration, offset;
}

class CatalogExtra {
  const CatalogExtra({required this.item, required this.kind});
  final Item item;
  final String kind;
}

class TitleFiles {
  const TitleFiles({
    required this.edition,
    required this.representation,
    required this.parts,
    required this.extras,
    required this.token,
  });
  final String edition, representation, token;
  final List<CatalogPart> parts;
  final List<CatalogExtra> extras;
}

class CatalogPlayback {
  const CatalogPlayback(this.db);
  final AppDatabase db;
  Future<List<({Item item, String edition, String representation})>> versions(
    Item item,
  ) async {
    final rows = await db
        .customSelect(
          '''SELECT r.item_id,e.title AS edition,r.payload FROM playable_representations r
      JOIN catalog_editions e ON e.id=r.edition_id WHERE e.work_id IN
      (SELECT x.work_id FROM playable_representations p JOIN catalog_editions x ON x.id=p.edition_id WHERE p.item_id=?)
      AND r.library_id=? ORDER BY e.title,r.item_id LIMIT 100''',
          variables: [Variable(item.id), Variable(item.libraryId)],
        )
        .get();
    final result = <({Item item, String edition, String representation})>[];
    for (final row in rows) {
      final asset = await db.getItemById(row.data['item_id'] as String);
      if (asset != null)
        result.add((
          item: asset,
          edition: row.data['edition'] as String,
          representation:
              (jsonDecode(row.data['payload'] as String)
                      as Map)['representation']
                  as String? ??
              '',
        ));
    }
    return result;
  }

  /// Specials and extras require explicit selection. Next episode is a later
  /// numbered episode in this show; duplicate representations are not episodes.
  Future<Item?> nextEpisode(Item item, {bool forward = true}) async {
    final metadata = await MediaCatalogRepository(db).metadata(item);
    final show = metadata['show'],
        season = metadata['season'],
        episode = metadata['episode'];
    if (show is! String ||
        season is! int ||
        episode is! int ||
        season == 0 ||
        metadata['extra'] == true)
      return null;
    final rows = await db
        .customSelect(
          '''SELECT i.id FROM items i
      JOIN catalog_facets sh ON sh.item_id=i.id AND sh.field='show'
      JOIN catalog_facets sn ON sn.item_id=i.id AND sn.field='season'
      JOIN catalog_facets ep ON ep.item_id=i.id AND ep.field='episode'
      WHERE i.library_id=? AND i.unavailable=0 AND sh.value=? AND sn.number>0
      AND (sn.number${forward ? '>' : '<'}? OR (sn.number=? AND ${forward ? 'ep.number' : "COALESCE((SELECT number FROM catalog_facets ending WHERE ending.item_id=i.id AND ending.field='episodeEnd'),ep.number)"}${forward ? '>' : '<'}?))
      AND NOT EXISTS(SELECT 1 FROM catalog_facets extra WHERE extra.item_id=i.id AND extra.field='extra' AND extra.value='true')
      AND NOT EXISTS(SELECT 1 FROM media_extras bonus WHERE bonus.item_id=i.id AND bonus.deleted=0)
      ORDER BY sn.number ${forward ? 'ASC' : 'DESC'},ep.number ${forward ? 'ASC' : 'DESC'},i.id LIMIT 1''',
          variables: [
            Variable(item.libraryId),
            Variable(show),
            Variable(season),
            Variable(season),
            Variable(
              forward && metadata['episodeEnd'] is int
                  ? metadata['episodeEnd'] as int
                  : episode,
            ),
          ],
        )
        .get();
    return rows.isEmpty
        ? null
        : db.getItemById(rows.first.data['id'] as String);
  }

  static const extraKinds = {
    'extra': 'Extra',
    'trailer': 'Trailer',
    'interview': 'Interview',
    'behindScenes': 'Behind the scenes',
    'deletedScene': 'Deleted scene',
    'booklet': 'Booklet',
    'featurette': 'Featurette',
    'scene': 'Scene',
    'short': 'Short',
    'other': 'Other',
  };

  static String partRoute(
    String representationId,
    String itemId, {
    double? position,
  }) => Uri(
    pathSegments: ['', 'player', itemId],
    queryParameters: {
      'title': representationId,
      if (position != null) 'position': '$position',
    },
  ).toString();

  Future<TitleFiles> files(Item item) => db.transaction(() async {
    final rep = await db
        .customSelect(
          'SELECT r.*,e.title AS edition,e.updated_at AS edition_updated FROM playable_representations r JOIN catalog_editions e ON e.id=r.edition_id WHERE r.item_id=? AND r.library_id=?',
          variables: [Variable(item.id), Variable(item.libraryId)],
        )
        .getSingleOrNull();
    if (rep == null)
      throw const FormatException(
        'This file has no catalog identity yet. Rescan the library first.',
      );
    final rows = await db
        .customSelect(
          'SELECT * FROM media_parts WHERE representation_id=? AND deleted=0 ORDER BY position,id LIMIT 101',
          variables: [Variable(item.id)],
        )
        .get();
    final extras = await db
        .customSelect(
          'SELECT * FROM media_extras WHERE representation_id=? AND deleted=0 ORDER BY position,id LIMIT 101',
          variables: [Variable(item.id)],
        )
        .get();
    if (rows.length > 100 || extras.length > 100)
      throw const FormatException(
        'A title supports at most 100 parts and 100 extras.',
      );
    final parts = <CatalogPart>[];
    for (final row in rows) {
      final asset = await db.getItemById(row.data['item_id'] as String);
      if (asset == null || asset.libraryId != item.libraryId)
        throw const FormatException('A part is no longer in this library.');
      final duration = (row.data['duration_seconds'] as num?)?.toDouble();
      final offset = (row.data['offset_seconds'] as num?)?.toDouble();
      if (duration == null ||
          !duration.isFinite ||
          duration <= 0 ||
          offset == null ||
          !offset.isFinite ||
          offset < 0) {
        throw const FormatException('A part has incomplete timing.');
      }
      parts.add(CatalogPart(item: asset, duration: duration, offset: offset));
    }
    final bonus = <CatalogExtra>[];
    for (final row in extras) {
      if (row.data['deleted'] == 1) continue;
      final asset = await db.getItemById(row.data['item_id'] as String);
      if (asset != null && asset.libraryId == item.libraryId) {
        bonus.add(CatalogExtra(item: asset, kind: row.data['kind'] as String));
      }
    }
    return TitleFiles(
      edition: rep.data['edition'] as String,
      representation:
          (jsonDecode(rep.data['payload'] as String) as Map)['representation']
              as String? ??
          '',
      parts: parts,
      extras: bonus,
      token: jsonEncode([
        rep.data,
        rows.map((row) => row.data).toList(),
        extras.map((row) => row.data).toList(),
      ]),
    );
  });

  /// All edits commit together; a stale editor cannot overwrite a newer layout.
  Future<void> saveFiles(
    Item item, {
    required String expected,
    required String edition,
    required String representation,
    required List<Item> parts,
    required List<CatalogExtra> extras,
  }) => db.transaction(() async {
    final current = await files(item);
    if (current.token != expected)
      throw const FormatException(
        'These title files changed elsewhere. Reload saved files before editing again.',
      );
    edition = edition.trim();
    representation = representation.trim();
    if (edition.isEmpty || edition.length > 200 || representation.length > 200)
      throw const FormatException(
        'Enter an edition name of at most 200 characters.',
      );
    if (extras.length > 100 ||
        extras.map((extra) => extra.item.id).toSet().length != extras.length)
      throw const FormatException('Choose at most 100 unique extras.');
    final partIds = parts.map((part) => part.id).toSet();
    for (final extra in extras) {
      final stored = await db.getItemById(extra.item.id);
      if (stored == null ||
          stored.libraryId != item.libraryId ||
          stored.id == item.id ||
          partIds.contains(stored.id) ||
          !extraKinds.containsKey(extra.kind)) {
        throw const FormatException(
          'Extras must be separate files from this library.',
        );
      }
    }
    final row = await db
        .customSelect(
          'SELECT r.payload,e.work_id,r.updated_at FROM playable_representations r JOIN catalog_editions e ON e.id=r.edition_id WHERE r.id=?',
          variables: [Variable(item.id)],
        )
        .getSingle();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = now > (row.data['updated_at'] as int)
        ? now
        : (row.data['updated_at'] as int) + 1;
    final editionId = stableId(
      'edition:${item.libraryId}:${row.data['work_id']}:$edition',
    );
    await db.customStatement(
      'INSERT OR IGNORE INTO catalog_editions(id,library_id,work_id,title,payload,updated_at) VALUES(?,?,?,?,?,?)',
      [
        editionId,
        item.libraryId,
        row.data['work_id'],
        edition,
        jsonEncode({'edition': edition}),
        updated,
      ],
    );
    final payload =
        Map<String, dynamic>.from(
            jsonDecode(row.data['payload'] as String) as Map,
          )
          ..['edition'] = edition
          ..['representation'] = representation;
    await db.customStatement(
      'UPDATE playable_representations SET edition_id=?,payload=?,updated_at=? WHERE id=? AND library_id=?',
      [editionId, jsonEncode(payload), updated, item.id, item.libraryId],
    );
    await defineParts(item, parts);
    await db.customStatement(
      'UPDATE media_extras SET deleted=1,updated_at=MAX(updated_at+1,?) WHERE representation_id=? AND deleted=0',
      [updated, item.id],
    );
    for (var position = 0; position < extras.length; position++) {
      final extra = extras[position];
      await db.customStatement(
        'INSERT INTO media_extras(id,library_id,representation_id,item_id,kind,position,deleted,updated_at) VALUES(?,?,?,?,?,?,0,?) ON CONFLICT(id) DO UPDATE SET kind=excluded.kind,position=excluded.position,deleted=0,updated_at=MAX(media_extras.updated_at+1,excluded.updated_at)',
        [
          stableId('extra:${item.id}:${extra.item.id}'),
          item.libraryId,
          item.id,
          extra.item.id,
          extra.kind,
          position,
          updated,
        ],
      );
    }
    db.notifyUpdates({TableUpdate.onTable(db.items)});
  });

  /// Empty membership restores single-file playback. Durations come from the
  /// current asset rows, never from an editable or stale title timeline.
  Future<void> defineParts(
    Item representation,
    List<Item> parts,
  ) => db.transaction(() async {
    final owner = await db.getItemById(representation.id);
    final identity = await db
        .customSelect(
          'SELECT library_id FROM playable_representations WHERE id=?',
          variables: [Variable(representation.id)],
        )
        .getSingleOrNull();
    if (owner == null ||
        owner.libraryId != representation.libraryId ||
        identity?.data['library_id'] != owner.libraryId ||
        owner.itemType != representation.itemType)
      throw const FormatException(
        'This representation no longer belongs to the expected library.',
      );
    if (parts.length > 100 ||
        parts.map((part) => part.id).toSet().length != parts.length) {
      throw const FormatException('Choose at most 100 unique parts.');
    }
    if (parts.isNotEmpty &&
        !{'video', 'audio'}.contains(representation.itemType))
      throw const FormatException(
        'Multipart playback requires audio or video.',
      );
    final current = <Item>[];
    for (final requested in parts) {
      final part = await db.getItemById(requested.id);
      if (part == null ||
          part.libraryId != representation.libraryId ||
          part.itemType != representation.itemType ||
          part.durationSeconds == null ||
          !part.durationSeconds!.isFinite ||
          part.durationSeconds! <= 0 ||
          part.durationSeconds! > 31536000 ||
          part.durationSeconds != requested.durationSeconds ||
          part.fingerprint != requested.fingerprint) {
        throw const FormatException(
          'Parts need unchanged files of the same media type, from this library, with known positive durations.',
        );
      }
      current.add(part);
    }
    final latest = await db
        .customSelect(
          'SELECT MAX(updated_at) AS stamp FROM media_parts WHERE representation_id=?',
          variables: [Variable(representation.id)],
        )
        .getSingle();
    final stamp = latest.data['stamp'] as int? ?? 0;
    final clock = DateTime.now().millisecondsSinceEpoch;
    final now = clock > stamp ? clock : stamp + 1;
    await db.customStatement(
      'UPDATE media_parts SET deleted=1,updated_at=? WHERE representation_id=? AND deleted=0',
      [now, representation.id],
    );
    var offset = 0.0;
    for (var index = 0; index < current.length; index++) {
      final part = current[index];
      await db.customStatement(
        'INSERT INTO media_parts(id,library_id,representation_id,item_id,position,duration_seconds,offset_seconds,deleted,updated_at) VALUES(?,?,?,?,?,?,?,0,?) ON CONFLICT(id) DO UPDATE SET position=excluded.position,duration_seconds=excluded.duration_seconds,offset_seconds=excluded.offset_seconds,deleted=0,updated_at=MAX(media_parts.updated_at+1,excluded.updated_at)',
        [
          stableId('${representation.id}:${part.id}'),
          representation.libraryId,
          representation.id,
          part.id,
          index,
          part.durationSeconds,
          offset,
          now,
        ],
      );
      offset += part.durationSeconds!;
    }
  });

  Future<void> setTitleCompletion(Item item, bool completed) =>
      db.transaction(() async {
        final parts = (await files(item)).parts;
        for (final asset
            in parts.isEmpty ? [item] : parts.map((part) => part.item)) {
          await db.setItemCompletion(item: asset, completed: completed);
        }
      });

  Future<List<CatalogPart>> _playableParts(String representationId) async {
    final item = await db.getItemById(representationId);
    if (item == null)
      throw const FormatException('This title no longer exists.');
    final parts = (await files(item)).parts;
    if (parts.isEmpty || parts.length > 100)
      throw const FormatException('This title has no multipart definition.');
    var offset = 0.0;
    for (final part in parts) {
      if ((part.offset - offset).abs() > .001 || part.item.unavailable)
        throw const FormatException(
          'A part is unavailable or the title timing needs to be saved again.',
        );
      offset += part.duration;
    }
    return parts;
  }

  Future<({String itemId, double position})> locatePart(
    String representationId,
    double seconds,
  ) async {
    if (!seconds.isFinite || seconds < 0)
      throw const FormatException('Invalid title position');
    final parts = await _playableParts(representationId);
    for (final part in parts) {
      if (seconds < part.offset + part.duration ||
          identical(part, parts.last)) {
        return (
          itemId: part.item.id,
          position: (seconds - part.offset).clamp(0, part.duration).toDouble(),
        );
      }
    }
    throw const FormatException('Part timing is incomplete');
  }

  Future<({String itemId, double position})> resumePart(
    String representationId,
  ) async {
    final parts = await _playableParts(representationId);
    for (final part in parts) {
      final progress = await db.getPlaybackByItemId(part.item.id);
      if (progress?.completed != true)
        return (
          itemId: part.item.id,
          position: (progress?.resumePositionSeconds ?? 0)
              .clamp(0, part.duration)
              .toDouble(),
        );
    }
    return (itemId: parts.first.item.id, position: 0.0);
  }

  Future<Item?> adjacentPart(
    String representationId,
    String itemId, {
    required bool forward,
  }) async {
    final parts = await _playableParts(representationId);
    final index = parts.indexWhere((part) => part.item.id == itemId);
    if (index < 0)
      throw const FormatException('This file is no longer part of the title.');
    final next = index + (forward ? 1 : -1);
    return next < 0 || next >= parts.length ? null : parts[next].item;
  }
}
