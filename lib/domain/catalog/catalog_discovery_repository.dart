import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import 'browse_options.dart';

class CatalogSearchPage {
  const CatalogSearchPage(this.entries, this.more, this.cursor);
  final List<GlobalSearchEntry> entries;
  final bool more;
  final (String, String)? cursor;
}

/// One SQL order/filter boundary for all result kinds; each page is bounded.
class CatalogDiscoveryRepository {
  const CatalogDiscoveryRepository(this.db);
  final AppDatabase db;
  Future<CatalogSearchPage> search(
    String query, {
    String kind = 'all',
    String? category,
    String? libraryId,
    bool byTitle = false,
    bool favorites = false,
    String? tag,
    (String, String)? after,
  }) async {
    query = query.trim();
    if (query.isEmpty) return const CatalogSearchPage([], false, null);
    if (query.length > 300)
      throw const FormatException('Search is limited to 300 characters');
    final terms = catalogTerms(query);
    // All operands are parameters. FTS operators are quoted as literal tokens.
    const itemHit =
        "(i.id IN (SELECT item_id FROM catalog_search WHERE catalog_search MATCH ?) OR (s.item_id IS NULL AND (i.title LIKE ? ESCAPE '\\' OR i.filename LIKE ? ESCAPE '\\')))";
    final like =
        '%${query.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
    final parts = <String>[], values = <Variable>[];
    const joins =
        'LEFT JOIN items i ON i.id=x.item_id LEFT JOIN catalog_search s ON s.item_id=i.id';
    if (kind == 'all' || kind == 'lesson') {
      parts.add(
        "SELECT 'lesson' AS kind,i.id AS ref_id,i.id AS item_id,i.library_id,COALESCE(s.title,i.user_title,i.title) AS title,i.updated_at,NULL AS position_seconds,NULL AS page_number FROM items i LEFT JOIN catalog_search s ON s.item_id=i.id WHERE $itemHit",
      );
      values.addAll([Variable(terms), Variable(like), Variable(like)]);
    }
    if (kind == 'all' || kind == 'note') {
      parts.add(
        "SELECT 'note' AS kind,x.id AS ref_id,x.item_id,x.library_id,x.content AS title,x.updated_at,x.position_seconds,x.page_number FROM notes x $joins WHERE x.deleted=0 AND (x.content LIKE ? ESCAPE '\\' OR $itemHit)",
      );
      values.addAll([
        Variable(like),
        Variable(terms),
        Variable(like),
        Variable(like),
      ]);
    }
    if (kind == 'all' || kind == 'bookmark') {
      parts.add(
        "SELECT 'bookmark' AS kind,x.id AS ref_id,x.item_id,x.library_id,x.title,x.updated_at,x.position_seconds,x.page_number FROM bookmarks x $joins WHERE x.deleted=0 AND (x.title LIKE ? ESCAPE '\\' OR x.description LIKE ? ESCAPE '\\' OR $itemHit)",
      );
      values.addAll([
        Variable(like),
        Variable(like),
        Variable(terms),
        Variable(like),
        Variable(like),
      ]);
    }
    if (kind == 'all' && !favorites && tag == null && category == null) {
      parts.add(
        "SELECT 'library' AS kind,id AS ref_id,NULL AS item_id,id AS library_id,title,updated_at,NULL AS position_seconds,NULL AS page_number FROM libraries WHERE title LIKE ? ESCAPE '\\' OR description LIKE ? ESCAPE '\\'",
      );
      values.addAll([Variable(like), Variable(like)]);
      parts.add(
        "SELECT 'section' AS kind,id AS ref_id,NULL AS item_id,library_id,title,updated_at,NULL AS position_seconds,NULL AS page_number FROM sections WHERE title LIKE ? ESCAPE '\\'",
      );
      values.add(Variable(like));
    }
    if (parts.isEmpty) return const CatalogSearchPage([], false, null);
    final filters = <String>['1=1'];
    if (libraryId != null) {
      filters.add('h.library_id=?');
      values.add(Variable(libraryId));
    }
    if (category != null) {
      filters.add(
        "EXISTS(SELECT 1 FROM catalog_facets c WHERE c.item_id=i.id AND c.field='category' AND c.value=?)",
      );
      values.add(Variable(category));
    }
    final org = organizationWhere(favorites: favorites, tag: tag);
    filters.addAll(org.sql);
    values.addAll(org.values);
    final order = byTitle
        ? 'lower(h.title)'
        : "printf('%020d',9999999999999-h.updated_at)";
    final rows = await db
        .customSelect(
          '''WITH hits AS (${parts.join(' UNION ALL ')}), ranked AS (
      SELECT h.*,l.title AS library_title,COALESCE(section.title,'General') AS section_title,
        COALESCE(p.percent_watched,r.percent_read,0) AS progress,
        COALESCE(p.completed,r.completed,0) AS done,$order AS sort_key,h.kind||':'||h.ref_id AS stable_key
      FROM hits h JOIN libraries l ON l.id=h.library_id
      LEFT JOIN items i ON i.id=h.item_id LEFT JOIN sections section ON section.id=i.section_id
      LEFT JOIN playback_progress p ON p.item_id=i.id LEFT JOIN reading_progress r ON r.item_id=i.id
      WHERE ${filters.join(' AND ')}) SELECT * FROM ranked
      ${after == null ? '' : 'WHERE (sort_key,stable_key)>(?,?)'} ORDER BY sort_key,stable_key LIMIT 49''',
          variables: [
            ...values,
            if (after != null) ...[Variable(after.$1), Variable(after.$2)],
          ],
        )
        .get();
    final entries = <GlobalSearchEntry>[];
    for (final row in rows.take(48)) {
      final data = row.data, id = row.data['item_id'] as String?;
      final item = id == null ? null : await db.getItemById(id);
      entries.add(
        GlobalSearchEntry(
          kind: data['kind'] as String,
          title: data['title'] as String,
          libraryTitle: data['library_title'] as String,
          sectionTitle: data['section_title'] as String,
          item: item,
          libraryId: data['library_id'] as String,
          progressPercent: (data['progress'] as num).toDouble(),
          completed: data['done'] == 1,
          updatedAt: data['updated_at'] as int,
          positionSeconds: (data['position_seconds'] as num?)?.toDouble(),
          pageNumber: data['page_number'] as int?,
          referenceId: data['ref_id'] as String,
        ),
      );
    }
    final last = rows.take(48).lastOrNull;
    return CatalogSearchPage(
      entries,
      rows.length > 48,
      last == null
          ? null
          : (
              last.data['sort_key'] as String,
              last.data['stable_key'] as String,
            ),
    );
  }

  Future<List<({String name, int count})>> tags({
    String? libraryId,
    String? category,
    String query = '',
    String? after,
  }) async {
    final rows = await db
        .customSelect(
          '''SELECT MIN(t.value) AS tag,COUNT(DISTINCT i.id) AS total
      FROM media_records o JOIN items i ON i.id=o.item_id,json_each(o.payload,'\$.tags') t
      WHERE o.kind='organization' AND o.deleted=0 AND o.library_id=i.library_id AND o.id='organization:'||i.id AND t.type='text'
        ${libraryId == null ? '' : 'AND i.library_id=?'}
        ${category == null ? '' : "AND EXISTS(SELECT 1 FROM catalog_facets f WHERE f.item_id=i.id AND f.field='category' AND f.value=?)"}
        AND instr(lower(t.value),lower(?))>0
      GROUP BY t.value COLLATE NOCASE ${after == null ? '' : 'HAVING MIN(t.value)>?'} ORDER BY MIN(t.value) LIMIT 61''',
          variables: [
            if (libraryId != null) Variable(libraryId),
            if (category != null) Variable(category),
            Variable(query),
            if (after != null) Variable(after),
          ],
        )
        .get();
    return [
      for (final row in rows)
        (name: row.data['tag'] as String, count: row.data['total'] as int),
    ];
  }
}
