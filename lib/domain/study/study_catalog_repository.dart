import 'dart:convert';
import 'package:drift/drift.dart';

import '../../data/db/app_database.dart';
import '../catalog/catalog_identity_store.dart';

enum StudyKind { notes, bookmarks }

class StudyPageResult {
  const StudyPageResult({
    required this.entries,
    required this.anchors,
    this.next,
  });
  final List<Map<String, dynamic>> entries;
  final Map<String, Map<String, dynamic>> anchors;
  final String? next;
  bool get hasMore => next != null;
  Map<String, dynamic> toJson() => {
    'entries': entries,
    'anchors': anchors,
    'next': next,
    'hasMore': hasMore,
  };
}

/// Item-scoped, deterministic pages shared by the native Study panel and host.
/// The byte ceiling can shorten a page; the cursor always follows its last row.
class StudyCatalogRepository {
  const StudyCatalogRepository(this.db);
  final AppDatabase db;
  static const pageBytes = 1024 * 1024;

  Selectable<QueryRow> _query(
    Item item,
    StudyKind kind,
    String query,
    String? cursor,
    int limit,
  ) {
    if (query.length > 256 || limit < 1 || limit > 100)
      throw const FormatException('Invalid Study page limits');
    final clauses = ['library_id=?', 'item_id=?', 'deleted=0'];
    final values = <Variable>[Variable(item.libraryId), Variable(item.id)];
    if (query.isNotEmpty) {
      final pattern =
          '%${query.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
      clauses.add(
        kind == StudyKind.notes
            ? "content LIKE ? ESCAPE '\\'"
            : "(title LIKE ? ESCAPE '\\' OR COALESCE(description,'') LIKE ? ESCAPE '\\')",
      );
      values.add(Variable(pattern));
      if (kind == StudyKind.bookmarks) values.add(Variable(pattern));
    }
    if (cursor != null) {
      if (cursor.length > 2048)
        throw const FormatException('Invalid Study cursor');
      final data = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(cursor))),
      );
      if (data is! Map ||
          data['version'] != 1 ||
          data['library'] != item.libraryId ||
          data['item'] != item.id ||
          data['kind'] != kind.name ||
          data['q'] != query ||
          data['stamp'] is! int ||
          data['stamp'] < 0 ||
          data['id'] is! String)
        throw const FormatException('Study cursor does not match this query');
      clauses.add('(updated_at<? OR (updated_at=? AND id<?))');
      values.addAll([
        Variable(data['stamp'] as int),
        Variable(data['stamp'] as int),
        Variable(data['id'] as String),
      ]);
    }
    return db.customSelect(
      'SELECT * FROM ${kind.name} WHERE ${clauses.join(' AND ')} ORDER BY updated_at DESC,id DESC LIMIT ?',
      variables: [...values, Variable(limit + 1)],
      readsFrom: kind == StudyKind.notes ? {db.notes} : {db.bookmarks},
    );
  }

  Future<StudyPageResult> page(
    Item item,
    StudyKind kind, {
    String query = '',
    String? cursor,
    int limit = 40,
  }) => db.transaction(
    () async => _result(
      item,
      kind,
      query.trim(),
      limit,
      await _query(item, kind, query.trim(), cursor, limit).get(),
    ),
  );

  Stream<StudyPageResult> watch(
    Item item,
    StudyKind kind, {
    String query = '',
    String? cursor,
    int limit = 40,
  }) => _query(
    item,
    kind,
    query.trim(),
    cursor,
    limit,
  ).watch().asyncMap((rows) => _result(item, kind, query.trim(), limit, rows));

  Future<StudyPageResult> _result(
    Item item,
    StudyKind kind,
    String query,
    int limit,
    List<QueryRow> rows,
  ) async {
    final entries = <Map<String, dynamic>>[];
    final anchors = <String, Map<String, dynamic>>{};
    final ids = rows
        .take(limit)
        .map(
          (row) =>
              '${kind == StudyKind.notes ? 'note' : 'bookmark'}:${row.data['id']}',
        )
        .toList();
    final anchorRows = ids.isEmpty
        ? <QueryRow>[]
        : await db
              .customSelect(
                'SELECT * FROM study_anchors WHERE library_id=? AND item_id=? AND id IN (${List.filled(ids.length, '?').join(',')})',
                variables: [
                  Variable(item.libraryId),
                  Variable(item.id),
                  ...ids.map(Variable.new),
                ],
              )
              .get();
    final anchorMap = {
      for (final row in anchorRows) row.data['id'] as String: row.data,
    };
    var bytes = 0;
    QueryRow? last;
    for (final row in rows.take(limit)) {
      final entry = kind == StudyKind.notes
          ? db.notes.map(row.data).toJson()
          : db.bookmarks.map(row.data).toJson();
      final anchorId =
          '${kind == StudyKind.notes ? 'note' : 'bookmark'}:${row.data['id']}';
      final rawAnchor = anchorMap[anchorId];
      final anchor = rawAnchor == null
          ? null
          : jsonDecode(
                  CatalogIdentityStore.transportRow(
                        'study_anchors',
                        rawAnchor,
                      )['payload']
                      as String,
                )
                as Map<String, dynamic>;
      final length = utf8
          .encode(jsonEncode({'entry': entry, 'anchor': anchor}))
          .length;
      if (bytes + length > pageBytes) {
        if (entries.isEmpty)
          throw const FormatException(
            'This Study entry exceeds the transfer limit. Shorten it on the host to sync it.',
          );
        break;
      }
      entries.add(entry);
      if (anchor != null) anchors[entry['id'] as String] = anchor;
      bytes += length;
      last = row;
    }
    final more = rows.length > entries.length;
    return StudyPageResult(
      entries: entries,
      anchors: anchors,
      next: !more || last == null
          ? null
          : base64Url.encode(
              utf8.encode(
                jsonEncode({
                  'version': 1,
                  'library': item.libraryId,
                  'item': item.id,
                  'kind': kind.name,
                  'q': query,
                  'stamp': last.data['updated_at'],
                  'id': last.data['id'],
                }),
              ),
            ),
    );
  }
}
