import 'dart:convert';
import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import 'media_catalog_repository.dart';

enum ShelfStatus { all, inProgress, unread, completed }

enum ReadingUnits { all, volumes, chapters }

class CategoryScope {
  const CategoryScope({
    required this.kind,
    this.libraryId,
    this.filters = const {},
    this.query = '',
    this.status = ShelfStatus.all,
    this.units = ReadingUnits.all,
  });
  final LibraryKind kind;
  final String? libraryId;

  /// Empty value selects the explicit missing-metadata bucket.
  final Map<String, String> filters;
  final String query;
  final ShelfStatus status;
  final ReadingUnits units;
  bool get reading => {LibraryKind.books, LibraryKind.comics}.contains(kind);
}

class CategoryGroup {
  const CategoryGroup({
    required this.value,
    required this.sort,
    required this.count,
    required this.completed,
    required this.inProgress,
    required this.cover,
    this.label,
    this.qualifier,
    this.unavailable = 0,
  });
  final String value, sort;
  final String? label, qualifier;
  final int count, completed, inProgress;
  final int unavailable;
  final Item cover;
}

class CategoryTitle {
  const CategoryTitle(
    this.item,
    this.metadata,
    this.progress,
    this.completed,
    this.libraryTitle,
  );
  final Item item;
  final Map<String, dynamic> metadata;
  final double progress;
  final bool completed;
  final String libraryTitle;
}

class CategoryPage {
  const CategoryPage({
    this.groups = const [],
    this.titles = const [],
    required this.more,
    this.cursor,
  });
  final List<CategoryGroup> groups;
  final List<CategoryTitle> titles;
  final bool more;
  final (String, String)? cursor;
}

/// One category contract for named libraries and cross-library browsing. SQL
/// groups/counts stay in SQLite; only one bounded page is materialized in Dart.
class CategoryBrowseRepository {
  const CategoryBrowseRepository(this.db);
  final AppDatabase db;
  static const pageSize = 48;
  static const groupingFields = {
    'show',
    'season',
    'artist',
    'album',
    'author',
    'series',
  };
  static String facet(String field) {
    if (!{
      ...groupingFields,
      'episode',
      'episodeEnd',
      'disc',
      'track',
      'volume',
      'chapter',
    }.contains(field)) {
      throw const FormatException('Unsupported category facet');
    }
    return "COALESCE((SELECT TRIM(value) FROM catalog_facets f WHERE f.item_id=i.id AND f.field='$field'),'')";
  }

  ({String sql, List<Variable> values}) _where(CategoryScope scope) {
    final clauses = <String>[
      "EXISTS(SELECT 1 FROM catalog_facets c WHERE c.item_id=i.id AND c.field='category' AND c.value=?)",
    ];
    final values = <Variable>[Variable(scope.kind.name)];
    if (scope.libraryId != null) {
      clauses.add('i.library_id=?');
      values.add(Variable(scope.libraryId!));
    }
    for (final filter in scope.filters.entries) {
      if (!groupingFields.contains(filter.key))
        throw const FormatException('Unsupported category group');
      clauses.add('${facet(filter.key)}=?');
      values.add(Variable(filter.value));
    }
    final query = scope.query.trim();
    if (query.isNotEmpty) {
      final terms = query
          .split(RegExp(r'\s+'))
          .take(8)
          .map((term) => '"${term.replaceAll('"', '""')}"*')
          .join(' AND ');
      clauses.add(
        'i.id IN (SELECT item_id FROM catalog_search WHERE catalog_search MATCH ?)',
      );
      values.add(Variable(terms));
    }
    final done = scope.reading
        ? 'COALESCE(r.completed,0)'
        : 'COALESCE(p.completed,0)';
    final percent = scope.reading
        ? 'COALESCE(r.percent_read,0)'
        : 'COALESCE(p.percent_watched,0)';
    switch (scope.status) {
      case ShelfStatus.all:
        break;
      case ShelfStatus.completed:
        clauses.add('$done=1');
      case ShelfStatus.inProgress:
        clauses.add('$done=0 AND $percent>0');
      case ShelfStatus.unread:
        clauses.add('$done=0 AND $percent<=0');
    }
    if (scope.units != ReadingUnits.all) {
      clauses.add(
        "${facet(scope.units == ReadingUnits.volumes ? 'volume' : 'chapter')}<>''",
      );
    }
    return (sql: clauses.join(' AND '), values: values);
  }

  static const _joins =
      'FROM items i JOIN libraries l ON l.id=i.library_id LEFT JOIN catalog_search s ON s.item_id=i.id LEFT JOIN playback_progress p ON p.item_id=i.id LEFT JOIN reading_progress r ON r.item_id=i.id';
  static String _number(String field) =>
      "COALESCE(NULLIF(${facet(field)},''),999999)";
  String _order(CategoryScope scope) {
    const title = 'COALESCE(s.title,i.user_title,i.title)';
    if (scope.kind == LibraryKind.television)
      return "printf('%08d:%08d:',${_number('season')},${_number('episode')}) || lower($title)";
    if (scope.kind == LibraryKind.music)
      return "lower(${facet('artist')}) || char(1) || lower(${facet('album')}) || char(1) || printf('%08d:%08d:',${_number('disc')},${_number('track')}) || lower($title)";
    if (scope.filters.containsKey('series'))
      return "CASE WHEN ${facet('volume')}<>'' THEN '0:' || printf('%020.8f',${_number('volume')}) WHEN ${facet('chapter')}<>'' THEN '1:' || printf('%020.8f',${_number('chapter')}) ELSE '2:' END || lower($title)";
    return 'lower($title)';
  }

  Future<CategoryPage> page(
    CategoryScope scope, {
    String? group,
    (String, String)? after,
  }) async {
    final where = _where(scope);
    final done = scope.reading
        ? 'COALESCE(r.completed,0)'
        : 'COALESCE(p.completed,0)';
    final percent = scope.reading
        ? 'COALESCE(r.percent_read,0)'
        : 'COALESCE(p.percent_watched,0)';
    if (group != null) {
      if (!groupingFields.contains(group))
        throw const FormatException('Unsupported category group');
      final albumRoot =
          group == 'album' && !scope.filters.containsKey('artist');
      final value = albumRoot
          ? "json_array(${facet('artist')},${facet('album')})"
          : facet(group);
      final sort = group == 'season'
          ? "CASE WHEN $value='' THEN '99999999' ELSE printf('%08d',CAST($value AS INTEGER)) END"
          : albumRoot
          ? "CASE WHEN ${facet('album')}='' THEN '1:' ELSE '0:' END || lower(${facet('album')}) || char(1) || lower(${facet('artist')})"
          : "CASE WHEN $value='' THEN '1:' ELSE '0:' END || lower($value)";
      final rows = await db
          .customSelect(
            '''WITH grouped_titles AS (
        SELECT $value AS group_value,$sort AS sort_key,COUNT(*) AS total,
        SUM($done) AS completed,SUM(CASE WHEN $done=0 AND $percent>0 THEN 1 ELSE 0 END) AS in_progress,
        SUM(i.unavailable) AS unavailable_count,
        MIN(i.id) AS cover_id $_joins WHERE ${where.sql} GROUP BY $value)
        SELECT * FROM grouped_titles ${after == null ? '' : 'WHERE sort_key>? OR (sort_key=? AND group_value>?)'}
        ORDER BY sort_key,group_value LIMIT ${pageSize + 1}''',
            variables: [
              ...where.values,
              if (after != null) ...[
                Variable(after.$1),
                Variable(after.$1),
                Variable(after.$2),
              ],
            ],
          )
          .get();
      final groups = <CategoryGroup>[];
      for (final row in rows.take(pageSize)) {
        final representativeOrder = scope.reading
            ? "CASE WHEN ${facet('volume')}<>'' THEN '0:' || printf('%020.8f',${_number('volume')}) WHEN ${facet('chapter')}<>'' THEN '1:' || printf('%020.8f',${_number('chapter')}) ELSE '2:' END || lower(COALESCE(s.title,i.title))"
            : _order(scope);
        final representative = await db
            .customSelect(
              'SELECT i.* $_joins WHERE ${where.sql} AND $value=? ORDER BY i.unavailable,$representativeOrder,i.id LIMIT 1',
              variables: [
                ...where.values,
                Variable(row.data['group_value'] as String),
              ],
            )
            .getSingleOrNull();
        final item = representative == null
            ? null
            : db.items.map(representative.data);
        final pair = albumRoot
            ? (jsonDecode(row.data['group_value'] as String) as List)
                  .cast<String>()
            : null;
        if (item != null)
          groups.add(
            CategoryGroup(
              value: row.data['group_value'] as String,
              sort: row.data['sort_key'] as String,
              count: row.data['total'] as int,
              label: pair?[1],
              qualifier: pair?[0],
              completed: row.data['completed'] as int,
              inProgress: row.data['in_progress'] as int,
              unavailable: row.data['unavailable_count'] as int,
              cover: item,
            ),
          );
      }
      return CategoryPage(
        groups: groups,
        more: rows.length > pageSize,
        cursor: groups.isEmpty ? null : (groups.last.sort, groups.last.value),
      );
    }
    final sort = _order(scope);
    final rows = await db
        .customSelect(
          '''WITH titles AS (
      SELECT i.*,l.title AS library_title,$sort AS sort_key,$done AS is_complete,$percent AS progress
      $_joins WHERE ${where.sql}) SELECT * FROM titles
      ${after == null ? '' : 'WHERE sort_key>? OR (sort_key=? AND id>?)'}
      ORDER BY sort_key,id LIMIT ${pageSize + 1}''',
          variables: [
            ...where.values,
            if (after != null) ...[
              Variable(after.$1),
              Variable(after.$1),
              Variable(after.$2),
            ],
          ],
        )
        .get();
    final titles = <CategoryTitle>[];
    final catalog = MediaCatalogRepository(db);
    for (final row in rows.take(pageSize)) {
      final item = db.items.map(row.data);
      titles.add(
        CategoryTitle(
          item,
          await catalog.metadata(item),
          (row.data['progress'] as num).toDouble(),
          row.data['is_complete'] == 1,
          row.data['library_title'] as String,
        ),
      );
    }
    return CategoryPage(
      titles: titles,
      more: rows.length > pageSize,
      cursor: titles.isEmpty
          ? null
          : (
              rows.take(pageSize).last.data['sort_key'] as String,
              titles.last.item.id,
            ),
    );
  }

  /// Scope queue, not just the visible page. Refuse oversized queues explicitly.
  Future<List<String>> queue(
    CategoryScope scope, {
    bool unfinishedOnly = false,
  }) async {
    final where = _where(scope), sort = _order(scope);
    final rows = await db
        .customSelect(
          'SELECT i.id $_joins WHERE ${where.sql} AND i.unavailable=0 AND i.item_type IN (\'audio\',\'video\') ${unfinishedOnly ? 'AND COALESCE(p.completed,0)=0' : ''} ORDER BY $sort,i.id LIMIT 10001',
          variables: where.values,
        )
        .get();
    if (rows.length > 10000)
      throw const FormatException(
        'This selection exceeds 10,000 tracks. Choose an artist, album or narrower search.',
      );
    return [for (final row in rows) row.data['id'] as String];
  }
}
