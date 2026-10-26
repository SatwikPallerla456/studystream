import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import 'media_catalog_repository.dart';
import 'browse_options.dart';

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
    this.sort = BrowseSort.natural,
    this.favorites = false,
    this.tag,
  });
  final LibraryKind kind;
  final String? libraryId;

  /// Empty value selects the explicit missing-metadata bucket.
  final Map<String, String> filters;
  final String query;
  final ShelfStatus status;
  final ReadingUnits units;
  final BrowseSort sort;
  final bool favorites;
  final String? tag;
  bool get reading => {
    LibraryKind.books,
    LibraryKind.comics,
    LibraryKind.documents,
  }.contains(kind);
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
    'month',
    'folder',
    'format',
  };
  static String facet(String field) {
    if (!{
      ...groupingFields,
      'episode',
      'episodeEnd',
      'airDate',
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
    final org = organizationWhere(favorites: scope.favorites, tag: scope.tag);
    clauses.addAll(org.sql);
    values.addAll(org.values);
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
    if (scope.sort != BrowseSort.natural) return browseItemOrder(scope.sort);
    const title = 'COALESCE(s.title,i.user_title,i.title)';
    if (scope.kind == LibraryKind.television)
      return "printf('%08d:%08d:',${_number('season')},${_number('episode')}) || lower($title)";
    if (scope.kind == LibraryKind.audiobooks)
      return "lower(${facet('author')}) || char(1) || lower(${facet('series')}) || printf('%08d:%08d:',${_number('disc')},${_number('track')}) || lower($title)";
    if (scope.kind == LibraryKind.podcasts)
      return "CASE WHEN ${facet('airDate')}='' THEN '1:' ELSE '0:' END || printf('%020d',99999999-CAST(replace(${facet('airDate')},'-','') AS INTEGER)) || printf('%08d:',${_number('track')}) || lower($title)";
    if ({LibraryKind.photos, LibraryKind.homeVideos}.contains(scope.kind))
      return "printf('%020d',9999999999999-COALESCE(i.modified_at,i.created_at)) || lower($title)";
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
      final bookRoot =
          group == 'series' &&
          scope.kind == LibraryKind.audiobooks &&
          !scope.filters.containsKey('author');
      final folderRoot = group == 'folder' && scope.libraryId == null;
      final albumRoot =
          group == 'album' && !scope.filters.containsKey('artist');
      final value = folderRoot
          ? "json_array(i.library_id,${facet('folder')})"
          : bookRoot
          ? "json_array(${facet('author')},${facet('series')})"
          : albumRoot
          ? "json_array(${facet('artist')},${facet('album')})"
          : facet(group);
      final naturalSort = folderRoot
          ? "lower(${facet('folder')}) || char(1) || i.library_id"
          : group == 'month'
          ? "CASE WHEN $value='' THEN '' ELSE $value END"
          : group == 'season'
          ? "CASE WHEN $value='' THEN '99999999' ELSE printf('%08d',CAST($value AS INTEGER)) END"
          : bookRoot
          ? "CASE WHEN ${facet('series')}='' THEN '1:' ELSE '0:' END || lower(${facet('series')}) || char(1) || lower(${facet('author')})"
          : albumRoot
          ? "CASE WHEN ${facet('album')}='' THEN '1:' ELSE '0:' END || lower(${facet('album')}) || char(1) || lower(${facet('artist')})"
          : "CASE WHEN $value='' THEN '1:' ELSE '0:' END || lower($value)";
      final sort = switch (scope.sort) {
        BrowseSort.natural => naturalSort,
        BrowseSort.title ||
        BrowseSort.titleDescending => 'lower(${facet(group)})',
        BrowseSort.newest => "printf('%020d',9999999999999-MAX(i.created_at))",
        BrowseSort.oldest => "printf('%020d',MIN(i.created_at))",
        BrowseSort.recent =>
          "printf('%020d',9999999999999-MAX(MAX(COALESCE(p.last_opened_at,0),COALESCE(r.last_opened_at,0))))",
      };
      final descending =
          scope.sort == BrowseSort.titleDescending ||
          scope.sort == BrowseSort.natural && group == 'month';
      final rows = await db
          .customSelect(
            '''WITH grouped_titles AS (
        SELECT $value AS group_value,$sort AS sort_key,COUNT(*) AS total,
        SUM($done) AS completed,SUM(CASE WHEN $done=0 AND $percent>0 THEN 1 ELSE 0 END) AS in_progress,
        SUM(i.unavailable) AS unavailable_count,
        MIN(i.id) AS cover_id $_joins WHERE ${where.sql} GROUP BY $value)
        SELECT * FROM grouped_titles ${after == null ? '' : "WHERE sort_key${descending ? '<' : '>'}? OR (sort_key=? AND group_value${descending ? '<' : '>'}?)"}
        ORDER BY sort_key ${descending ? 'DESC' : 'ASC'},group_value ${descending ? 'DESC' : 'ASC'} LIMIT ${pageSize + 1}''',
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
        final pair = (albumRoot || bookRoot || folderRoot)
            ? (jsonDecode(row.data['group_value'] as String) as List)
                  .cast<String>()
            : null;
        String? folderLabel;
        if (item != null && group == 'folder') {
          final raw = folderRoot ? pair![1] : row.data['group_value'] as String;
          final sources = await MediaCatalogRepository(
            db,
          ).sources(item.libraryId);
          final source = sources
              .where(
                (s) =>
                    s.namespace.isNotEmpty &&
                    (raw == s.namespace || raw.startsWith('${s.namespace}/')),
              )
              .firstOrNull;
          if (source != null) {
            final relative = raw
                .substring(source.namespace.length)
                .replaceFirst(RegExp(r'^/'), '');
            folderLabel =
                '${path.basename(source.root)}${relative.isEmpty ? '' : ' / $relative'}';
          }
        }
        String? libraryLabel;
        if (item != null && folderRoot) {
          libraryLabel =
              (await db
                          .customSelect(
                            'SELECT title FROM libraries WHERE id=?',
                            variables: [Variable(item.libraryId)],
                          )
                          .getSingle())
                      .data['title']
                  as String;
        }
        if (item != null)
          groups.add(
            CategoryGroup(
              value: row.data['group_value'] as String,
              sort: row.data['sort_key'] as String,
              count: row.data['total'] as int,
              label: folderLabel ?? pair?[1],
              qualifier: folderRoot ? libraryLabel : pair?[0],
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
    final descending = scope.sort == BrowseSort.titleDescending;
    final rows = await db
        .customSelect(
          '''WITH titles AS (
      SELECT i.*,l.title AS library_title,$sort AS sort_key,$done AS is_complete,$percent AS progress
      $_joins WHERE ${where.sql}) SELECT * FROM titles
      ${after == null ? '' : "WHERE sort_key${descending ? '<' : '>'}? OR (sort_key=? AND id${descending ? '<' : '>'}?)"}
      ORDER BY sort_key ${descending ? 'DESC' : 'ASC'},id ${descending ? 'DESC' : 'ASC'} LIMIT ${pageSize + 1}''',
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

  Future<Item?> photo(
    CategoryScope scope, {
    Item? current,
    bool forward = true,
    String? initialId,
  }) async {
    final where = _where(scope), sort = _order(scope);
    final ascending = forward != (scope.sort == BrowseSort.titleDescending);
    final rows = await db
        .customSelect(
          '''WITH photos AS (
      SELECT i.*,$sort AS sort_key $_joins WHERE ${where.sql} AND i.item_type='image' AND i.unavailable=0)
      SELECT * FROM photos ${initialId != null
              ? 'WHERE id=?'
              : current == null
              ? ''
              : "WHERE (sort_key,id) ${ascending ? '>' : '<'} (SELECT sort_key,id FROM photos WHERE id=?)"}
      ORDER BY sort_key ${ascending ? 'ASC' : 'DESC'},id ${ascending ? 'ASC' : 'DESC'} LIMIT 1''',
          variables: [
            ...where.values,
            if (initialId != null)
              Variable(initialId)
            else if (current != null)
              Variable(current.id),
          ],
        )
        .getSingleOrNull();
    return rows == null ? null : db.items.map(rows.data);
  }

  /// Scope queue, not just the visible page. Refuse oversized queues explicitly.
  Future<List<String>> queue(
    CategoryScope scope, {
    bool unfinishedOnly = false,
  }) async {
    final where = _where(scope), sort = _order(scope);
    final rows = await db
        .customSelect(
          'SELECT i.id $_joins WHERE ${where.sql} AND i.unavailable=0 AND i.item_type IN (\'audio\',\'video\') AND NOT EXISTS(SELECT 1 FROM catalog_facets x WHERE x.item_id=i.id AND x.field=\'extra\' AND x.value=\'true\') AND NOT EXISTS(SELECT 1 FROM media_extras e WHERE e.item_id=i.id AND e.deleted=0) ${unfinishedOnly ? 'AND COALESCE(p.completed,0)=0' : ''} ORDER BY $sort ${scope.sort == BrowseSort.titleDescending ? 'DESC' : 'ASC'},i.id ${scope.sort == BrowseSort.titleDescending ? 'DESC' : 'ASC'} LIMIT 10001',
          variables: where.values,
        )
        .get();
    if (rows.length > 10000)
      throw const FormatException(
        'This selection exceeds 10,000 files. Choose a narrower group or search.',
      );
    return [for (final row in rows) row.data['id'] as String];
  }
}
