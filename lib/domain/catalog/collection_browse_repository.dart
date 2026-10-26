import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import 'media_catalog_repository.dart';

class CollectionMember {
  const CollectionMember(
    this.item,
    this.title,
    this.position,
    this.progress,
    this.completed,
  );
  final Item item;
  final String title;
  final int position;
  final double progress;
  final bool completed;
}

class CollectionMembersPage {
  const CollectionMembersPage(this.members, this.more, this.cursor);
  final List<CollectionMember> members;
  final bool more;
  final (int, String)? cursor;
}

class CollectionSummary {
  const CollectionSummary(
    this.record,
    this.libraryTitle,
    this.total,
    this.playable,
    this.photos,
    this.readable,
  );
  final MediaRecord record;
  final String libraryTitle;
  final int total, playable, photos, readable;
}

/// Membership order and named-library ownership are authoritative. No catalog
/// materialization or provider-generated album heuristics are used here.
class CollectionBrowseRepository {
  const CollectionBrowseRepository(this.db);
  final AppDatabase db;
  static const _join =
      "FROM catalog_memberships m JOIN media_records c ON c.id=m.collection_id AND c.library_id=m.library_id AND c.deleted=0 AND c.kind IN ('collection','album') JOIN items i ON i.id=m.item_id AND i.library_id=m.library_id LEFT JOIN catalog_search s ON s.item_id=i.id LEFT JOIN playback_progress p ON p.item_id=i.id LEFT JOIN reading_progress r ON r.item_id=i.id";
  Future<CollectionSummary?> summary(String id) async {
    final record = await MediaCatalogRepository(db).record(id);
    if (record == null || !{'collection', 'album'}.contains(record.kind))
      return null;
    final row = await db
        .customSelect(
          '''SELECT COUNT(*) AS total,
      SUM(CASE WHEN i.unavailable=0 AND i.item_type IN ('audio','video') THEN 1 ELSE 0 END) AS playable,
      SUM(CASE WHEN i.unavailable=0 AND i.item_type='image' THEN 1 ELSE 0 END) AS photos,
      SUM(CASE WHEN i.unavailable=0 AND i.item_type NOT IN ('image','audio','video') THEN 1 ELSE 0 END) AS readable
      $_join WHERE m.collection_id=? AND m.deleted=0''',
          variables: [Variable(id)],
        )
        .getSingle();
    return CollectionSummary(
      record,
      (await db.getLibraryById(record.libraryId))?.title ?? 'Library',
      row.data['total'] as int,
      (row.data['playable'] as num?)?.toInt() ?? 0,
      (row.data['photos'] as num?)?.toInt() ?? 0,
      (row.data['readable'] as num?)?.toInt() ?? 0,
    );
  }

  Future<CollectionMembersPage> page(String id, {(int, String)? after}) async {
    final rows = await db
        .customSelect(
          '''SELECT i.*,COALESCE(s.title,i.user_title,i.title) AS display_title,
      m.position AS member_position,COALESCE(p.percent_watched,r.percent_read,0) AS progress,
      COALESCE(p.completed,r.completed,0) AS done $_join WHERE m.collection_id=? AND m.deleted=0
      ${after == null ? '' : 'AND (m.position,i.id)>(?,?)'} ORDER BY m.position,i.id LIMIT 49''',
          variables: [
            Variable(id),
            if (after != null) ...[Variable(after.$1), Variable(after.$2)],
          ],
        )
        .get();
    final members = [
      for (final row in rows.take(48))
        CollectionMember(
          db.items.map(row.data),
          row.data['display_title'] as String,
          row.data['member_position'] as int,
          (row.data['progress'] as num).toDouble(),
          row.data['done'] == 1,
        ),
    ];
    return CollectionMembersPage(
      members,
      rows.length > 48,
      members.isEmpty ? null : (members.last.position, members.last.item.id),
    );
  }

  Future<List<String>> queue(String id) async {
    final rows = await db
        .customSelect(
          "SELECT i.id $_join WHERE m.collection_id=? AND m.deleted=0 AND i.unavailable=0 AND i.item_type IN ('audio','video') ORDER BY m.position,i.id LIMIT 1001",
          variables: [Variable(id)],
        )
        .get();
    if (rows.length > 1000)
      throw const FormatException(
        'This collection exceeds 1,000 playable files. Narrow its membership.',
      );
    return [for (final row in rows) row.data['id'] as String];
  }

  Future<Item?> readingStart(String id) async {
    final row = await db
        .customSelect(
          "SELECT i.* $_join WHERE m.collection_id=? AND m.deleted=0 AND i.unavailable=0 AND i.item_type NOT IN ('audio','video','image') AND COALESCE(r.completed,0)=0 ORDER BY CASE WHEN COALESCE(r.percent_read,0)>0 OR COALESCE(r.last_opened_at,0)>0 THEN 0 ELSE 1 END,m.position,i.id LIMIT 1",
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    return row == null ? null : db.items.map(row.data);
  }

  Future<Item?> photo(
    String id, {
    Item? current,
    bool forward = true,
    String? initialId,
  }) async {
    final rows = await db
        .customSelect(
          '''WITH photos AS (SELECT i.*,m.position AS member_position $_join
      WHERE m.collection_id=? AND m.deleted=0 AND i.unavailable=0 AND i.item_type='image')
      SELECT * FROM photos ${initialId != null
              ? 'WHERE id=?'
              : current == null
              ? ''
              : "WHERE (member_position,id) ${forward ? '>' : '<'} (SELECT member_position,id FROM photos WHERE id=?)"}
      ORDER BY member_position ${forward ? 'ASC' : 'DESC'},id ${forward ? 'ASC' : 'DESC'} LIMIT 1''',
          variables: [
            Variable(id),
            if (initialId != null)
              Variable(initialId)
            else if (current != null)
              Variable(current.id),
          ],
        )
        .getSingleOrNull();
    return rows == null ? null : db.items.map(rows.data);
  }
}
