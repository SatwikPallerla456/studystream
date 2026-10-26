import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart' as d;
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';
import '../db/app_database.dart';
import '../reader/book_page_source.dart';
import '../reader/publication_content.dart';
import '../reader/publication_server.dart';
import '../reader/safe_book_archive.dart';
import '../../domain/catalog/category_browse_repository.dart';
import '../../domain/catalog/collection_browse_repository.dart';
import '../../domain/catalog/browse_options.dart';
import '../../domain/catalog/catalog_playback.dart';
import '../../domain/catalog/catalog_identity_store.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/catalog/media_record_contract.dart';
import '../../domain/reader/reader_contract.dart';
import '../../domain/reader/reader_session_store.dart';
import 'approved_media_source.dart';
import 'sync_snapshot_merger.dart';
import 'sync_state_store.dart';
import '../../domain/services/sync_intent.dart';

/// The browser uses the native catalog and reader identities; no filesystem path
/// or broadened source/library permission is part of this transport.
class BrowserExperienceApi {
  BrowserExperienceApi(this.db);
  final AppDatabase db;
  int _jobs = 0;
  final _waiting = Queue<Completer<bool>>();
  Future<bool> _acquire() async {
    if (_jobs < 4) {
      _jobs++;
      return true;
    }
    if (_waiting.length >= 16) return false;
    final pending = Completer<bool>();
    _waiting.add(pending);
    return pending.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _waiting.remove(pending);
        return false;
      },
    );
  }

  void _release() {
    _jobs--;
    if (_waiting.isNotEmpty) {
      _jobs++;
      _waiting.removeFirst().complete(true);
    }
  }

  Future<void> _json(HttpRequest r, int code, Object data) async {
    r.response.statusCode = code;
    r.response.headers.contentType = ContentType.json;
    final encoded = utf8.encode(jsonEncode(data));
    if (encoded.length > 8 * 1024 * 1024) {
      r.response.statusCode = 413;
      r.response.write(
        jsonEncode({
          'error':
              'Browser response exceeds 8 MiB. Narrow the library/query or use the native reader.',
        }),
      );
    } else if (r.method != 'HEAD')
      r.response.add(encoded);
    await r.response.close();
  }

  Future<Map<String, dynamic>> _body(HttpRequest r) async {
    final bytes = <int>[], iterator = StreamIterator<List<int>>(r);
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    try {
      while (true) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero)
          throw const FormatException('Reader request timed out');
        if (!await iterator.moveNext().timeout(
          remaining,
          onTimeout: () =>
              throw const FormatException('Reader request timed out'),
        ))
          break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > 65536)
          throw const FormatException('Reader request exceeds 64 KiB');
        bytes.addAll(chunk);
      }
    } finally {
      await iterator.cancel();
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>)
      throw const FormatException('Expected a JSON object');
    return value;
  }

  Future<Map<String, dynamic>> itemJson(Item item) async {
    final catalog = MediaCatalogRepository(db),
        metadata = await MediaCatalogRepository(db).metadata(item);
    return {
      ...item.toJson(),
      'filePath': '',
      'thumbnailPath': null,
      'fingerprint': null,
      'libraryKind': (await catalog.libraryKind(item.libraryId)).name,
      'metadata': {
        for (final key in MediaRecordContract.fields('metadata')!)
          if (metadata.containsKey(key)) key: metadata[key],
      },
      'playback': await _progressJson('playback', item.id),
      'reading': await _progressJson('reading', item.id),
    };
  }

  Future<Map<String, dynamic>?> _progressJson(String kind, String id) =>
      db.transaction(() async {
        final store = SyncStateStore(db),
            row = await SyncStateStore(db).row(kind, id);
        return row == null ? null : await store.decorate(kind, row);
      });

  String _encode(Object value) =>
      base64UrlEncode(utf8.encode(jsonEncode(value)));
  dynamic _decode(String raw) {
    if (raw.length > 4096) throw const FormatException('Cursor too large');
    return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(raw))));
  }

  Future<bool> handle(
    HttpRequest r,
    KnownDevice device,
    Set<String> browse,
    Set<String> stream,
    Set<String> mutate,
  ) async {
    final p = r.uri.pathSegments;
    if (p.length < 2 ||
        p[0] != 'v2' ||
        !{
          'browse',
          'details',
          'reader',
          'publication',
          'progress',
        }.contains(p[1]))
      return false;
    final q = r.uri.queryParameters;
    if (p[1] == 'browse' && r.method == 'GET') {
      final library = q['library'];
      if (library != null && !browse.contains(library)) {
        await _json(r, 403, {'error': 'Library not approved'});
        return true;
      }
      final kind = q['kind'] ?? 'movies', query = q['q'] ?? '';
      if (q.entries.any((e) => e.key.length > 100 || e.value.length > 4096))
        throw const FormatException('Browser query exceeds the limit');
      if (query.length > 512) throw const FormatException('Search is too long');
      final sortedQuery = q.entries.where((e) => e.key != 'cursor').toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final signature = jsonEncode(
        Map<String, String>.fromEntries(sortedQuery),
      );
      dynamic after;
      if (q['cursor'] != null) {
        final data = _decode(q['cursor']!);
        if (data is! Map ||
            data['scope'] != signature ||
            data['allowed'] != jsonEncode([...browse]..sort()))
          throw const FormatException('Cursor does not match library scope');
        after = data['after'];
      }
      String? cursor(Object? value) => value == null
          ? null
          : _encode({
              'scope': signature,
              'allowed': jsonEncode([...browse]..sort()),
              'after': value,
            });
      final collection = q['members'];
      if (after != null) {
        final member = collection != null;
        final valid = kind == 'collections' && !member
            ? after is String
            : after is List &&
                  after.length == 2 &&
                  (member ? after[0] is int : after[0] is String) &&
                  after[1] is String;
        if (!valid) throw const FormatException('Invalid browser continuation');
      }
      if (collection != null) {
        final repo = CollectionBrowseRepository(db),
            summary = await CollectionBrowseRepository(db).summary(collection);
        if (summary == null ||
            !browse.contains(summary.record.libraryId) ||
            library != null && library != summary.record.libraryId) {
          await _json(r, 404, {'error': 'Collection unavailable'});
          return true;
        }
        final page = await repo.page(
          collection,
          query: query,
          after: after == null
              ? null
              : ((after as List)[0] as int, after[1] as String),
        );
        await _json(r, 200, {
          'title': summary.record.data['title'],
          'items': [for (final row in page.members) await itemJson(row.item)],
          'groups': [],
          'next': page.more ? cursor([page.cursor!.$1, page.cursor!.$2]) : null,
        });
        return true;
      }
      if (kind == 'collections') {
        final scopes = library == null ? browse : {library};
        if (scopes.isEmpty) {
          await _json(r, 200, {'groups': [], 'items': [], 'next': null});
          return true;
        }
        final rows = await db
            .customSelect(
              "SELECT c.* FROM media_records c WHERE c.deleted=0 AND c.kind IN ('collection','album') AND c.library_id IN (${scopes.map((_) => '?').join(',')}) AND lower(json_extract(c.payload,'\$.title')) LIKE ? ${after == null ? '' : 'AND c.id>?'} ORDER BY c.id LIMIT 49",
              variables: [
                ...scopes.map(d.Variable.new),
                d.Variable('%${query.toLowerCase()}%'),
                if (after != null) d.Variable(after as String),
              ],
            )
            .get();
        final groups = <Map<String, dynamic>>[];
        for (final row in rows.take(48)) {
          final record = MediaRecord(row.data),
              summary = await CollectionBrowseRepository(
                db,
              ).summary(row.data['id'] as String);
          if (summary == null) continue;
          final first = await CollectionBrowseRepository(db).page(record.id);
          groups.add({
            'value': record.id,
            'label': record.data['title'],
            'count': summary.total,
            'group': 'collection',
            'cover': first.members.isEmpty
                ? null
                : await itemJson(first.members.first.item),
          });
        }
        await _json(r, 200, {
          'groups': groups,
          'items': [],
          'next': rows.length > 48 ? cursor(rows[47].data['id']) : null,
        });
        return true;
      }
      final category = LibraryKind.values
          .where((k) => k.name == kind)
          .firstOrNull;
      if (category == null) throw const FormatException('Unknown category');
      final filters = <String, String>{
        for (final key in CategoryBrowseRepository.groupingFields)
          if (q.containsKey('f.$key')) key: q['f.$key']!,
      };
      final sort =
          BrowseSort.values.where((v) => v.name == q['sort']).firstOrNull ??
          BrowseSort.natural;
      final scope = CategoryScope(
        kind: category,
        libraryId: library,
        libraryIds: browse,
        query: query,
        filters: filters,
        sort: sort,
      );
      final page = await CategoryBrowseRepository(db).page(
        scope,
        group: q['group'],
        after: after == null
            ? null
            : ((after as List)[0] as String, after[1] as String),
      );
      await _json(r, 200, {
        'groups': [
          for (final g in page.groups)
            {
              'value': g.value,
              'label': g.label ?? g.value,
              'qualifier': g.qualifier,
              'count': g.count,
              'completed': g.completed,
              'inProgress': g.inProgress,
              'group': q['group'],
              'cover': await itemJson(g.cover),
            },
        ],
        'items': [for (final row in page.titles) await itemJson(row.item)],
        'next': page.more ? cursor([page.cursor!.$1, page.cursor!.$2]) : null,
      });
      return true;
    }
    if (p.length < 3) return false;
    final item = await db.getItemById(p[2]);
    final allowed = p[1] == 'progress'
        ? mutate
        : p[1] == 'details'
        ? browse
        : stream;
    if (item == null ||
        !allowed.contains(item.libraryId) ||
        p[1] != 'details' && item.unavailable) {
      await _json(r, 404, {'error': 'Title unavailable or not approved'});
      return true;
    }
    if (p[1] == 'progress') {
      if (r.method != 'POST') {
        await _json(r, 405, {'error': 'Use POST for progress'});
        return true;
      }
      await _savePlayback(r, device, item);
      return true;
    }
    if (p[1] == 'details' && r.method == 'GET') {
      final playback = CatalogPlayback(db);
      final versions = await playback.versions(item);
      List<Map<String, dynamic>> parts = [], extras = [];
      String? filesMessage;
      try {
        final files = await playback.files(item);
        parts = [
          for (final v in files.parts)
            {
              'item': await itemJson(v.item),
              'duration': v.duration,
              'offset': v.offset,
            },
        ];
        extras = [
          for (final v in files.extras)
            {'item': await itemJson(v.item), 'kind': v.kind},
        ];
      } on FormatException catch (e) {
        filesMessage = e.message;
      }
      final facts = await db
          .customSelect(
            'SELECT payload FROM technical_media WHERE item_id=?',
            variables: [d.Variable(item.id)],
          )
          .getSingleOrNull();
      final technical = facts == null
          ? <String, dynamic>{}
          : jsonDecode(facts.data['payload'] as String) as Map;
      await _json(r, 200, {
        'item': await itemJson(item),
        'canStream': stream.contains(item.libraryId) && !item.unavailable,
        'canMutate': mutate.contains(item.libraryId),
        'versions': [
          for (final v in versions)
            {
              'item': await itemJson(v.item),
              'edition': v.edition,
              'representation': v.representation,
            },
        ],
        'parts': parts,
        'extras': extras,
        'filesMessage': filesMessage,
        'technical': {
          for (final k in [
            'container',
            'codec',
            'durationSeconds',
            'width',
            'height',
            'channels',
            'sampleRate',
            'bitrate',
            'analysisState',
          ])
            if (technical.containsKey(k)) k: technical[k],
        },
      });
      return true;
    }
    if (p[1] == 'reader' && !browse.contains(item.libraryId)) {
      await _json(r, 403, {
        'error': 'Reader metadata requires browse permission',
      });
      return true;
    }
    if (!{'pdf', 'epub', 'cbz'}.contains(item.itemType)) {
      await _json(r, 422, {'error': 'This format has no browser reader'});
      return true;
    }
    if (!{'GET', 'HEAD', 'POST'}.contains(r.method)) {
      await _json(r, 405, {'error': 'Method unavailable'});
      return true;
    }
    if (!await _acquire()) {
      await _json(r, 503, {'error': 'Reader busy. Retry shortly.'});
      return true;
    }
    try {
      final file = await resolveApprovedMedia(db, item);
      if (item.itemType == 'pdf') {
        final doc = await PdfDocument.openFile(file.path);
        try {
          if (doc.pages.length > 10000)
            throw const FormatException(
              'Use the native reader for PDFs over 10,000 pages',
            );
          await _reader(
            r,
            device,
            item,
            doc.pages.length,
            (n) => 'pdf:$n',
            null,
            doc,
            mutate,
          );
        } finally {
          await doc.dispose();
        }
      } else {
        final source = await ArchiveBookSource.open(
          file.path,
          epub: item.itemType == 'epub',
        );
        try {
          if (p[1] == 'publication' && !{'GET', 'HEAD'}.contains(r.method)) {
            await _json(r, 405, {'error': 'Publication assets are read-only'});
          } else if (p[1] == 'publication')
            await _publication(r, item, source, p.skip(3).join('/'));
          else
            await _reader(
              r,
              device,
              item,
              source.pageCount,
              source.locator,
              source,
              null,
              mutate,
            );
        } finally {
          await source.dispose();
        }
      }
    } on MediaSourceException catch (e) {
      await _json(r, e.statusCode, {'error': e.message});
    } finally {
      _release();
    }
    return true;
  }

  Future<void> _savePlayback(
    HttpRequest r,
    KnownDevice device,
    Item item,
  ) async {
    if (!{'audio', 'video'}.contains(item.itemType))
      throw const FormatException('Not playable media');
    final body = await _body(r), raw = body['context'];
    if (raw is! Map)
      throw const FormatException('A progress context is required');
    final ctx = SyncIntent.state({'syncProgress': raw});
    double number(String key, double low, double high) {
      final v = body[key];
      if (v is! num || !v.isFinite || v < low || v > high)
        throw FormatException('Invalid $key');
      return v.toDouble();
    }

    final duration = number('duration', 0.001, 315360000),
        position = number('position', 0, duration),
        speed = number('speed', .1, 8);
    final intent = body['intent'];
    if (intent != null && intent != 'position')
      throw const FormatException('Invalid position intent');
    try {
      await db.transaction(() async {
        final old = await db.getPlaybackByItemId(item.id),
            now = DateTime.now().millisecondsSinceEpoch;
        final done =
            old?.manualCompletion ??
            (old?.completed == true ||
                body['ended'] == true ||
                position / duration >= .9);
        await db.upsertPlayback(
          PlaybackProgressCompanion(
            itemId: d.Value(item.id),
            lastPositionSeconds: d.Value(position),
            resumePositionSeconds: d.Value(
              done ? 0.0 : max(0.0, position - 10),
            ),
            durationSeconds: d.Value(duration),
            percentWatched: d.Value(
              max(
                old?.percentWatched ?? 0.0,
                done ? 100.0 : position / duration * 100,
              ),
            ),
            completed: d.Value(done),
            manualCompletion: d.Value(old?.manualCompletion),
            playbackSpeed: d.Value(speed),
            lastOpenedAt: d.Value(now),
            lastEventAt: d.Value(now),
            deviceId: d.Value(device.id),
            version: d.Value((old?.version ?? 0) + 1),
          ),
          syncContext: ctx,
          intent: intent as String?,
        );
      });
      await _json(r, 200, {
        'playback': await _progressJson('playback', item.id),
      });
    } on ProgressContextChanged {
      await _json(r, 409, {
        'error':
            'Progress changed on another player. Reopen the title before saving.',
      });
    }
  }

  Future<void> _reader(
    HttpRequest r,
    KnownDevice device,
    Item item,
    int count,
    String Function(int) key,
    ArchiveBookSource? source,
    PdfDocument? pdf,
    Set<String> mutate,
  ) async {
    final revision = await CatalogIdentityStore(db).contentRevision(item),
        catalog = MediaCatalogRepository(db);
    final record = await catalog.record('reader:${item.id}'),
        progress = await db.getReadingByItemId(item.id);
    final p = r.uri.pathSegments;
    if (p.length == 3 && r.method == 'GET') {
      await _json(r, 200, {
        'itemId': item.id,
        'revision': revision,
        'pages': count,
        'reflowable': source?.reflowable ?? false,
        'version': progress?.version ?? 0,
        'updatedAt': record?.updatedAt ?? 0,
        'settings': {
          ...await ReaderSessionStore(db, item).settings(),
          ...?record?.data,
        },
        'reading': await _progressJson('reading', item.id),
        'context': await SyncStateStore(db).context('reading', item.id),
        'canMutate': mutate.contains(item.libraryId),
        'sections': source == null
            ? []
            : [
                for (var i = 1; i <= count; i++)
                  {
                    'page': i,
                    'key': key(i),
                    'title': source.titles[i - 1],
                    'publication': source.publicationPage(i),
                  },
              ],
        'contents': [
          for (final entry in source?.contents ?? <PublicationDestination>[])
            {
              'title': entry.title,
              'page': entry.page,
              'fragment': entry.fragment,
              'depth': entry.depth,
            },
        ],
      });
      return;
    }
    if (p.length == 5 && p[3] == 'text' && r.method == 'GET' && pdf != null) {
      final page = int.tryParse(p[4]) ?? 0;
      if (page < 1 || page > count)
        throw const FormatException('Invalid PDF page');
      final text = await pdf.pages[page - 1].loadStructuredText();
      final value = text.fullText;
      if (value.length > 1000000)
        throw const FormatException('PDF page text exceeds the browser budget');
      await _json(r, 200, {
        'page': page,
        'key': key(page),
        'text': value,
        'unit': 'pdfCharacter',
      });
      return;
    }
    if (p.length == 5 &&
        p[3] == 'section' &&
        r.method == 'GET' &&
        source != null) {
      final page = int.tryParse(p[4]) ?? 0;
      if (page < 1 || page > count)
        throw const FormatException('Invalid section');
      await _publication(r, item, source, key(page));
      return;
    }
    if (r.method != 'POST' ||
        p.length > 4 ||
        p.length == 4 && p[3] != 'study') {
      await _json(r, 404, {'error': 'Reader route unavailable'});
      return;
    }
    if (!mutate.contains(item.libraryId)) {
      await _json(r, 403, {
        'error': 'This library is read-only for this device',
      });
      return;
    }
    final body = await _body(r);
    if (body['locator'] is! String)
      throw const FormatException('A reader locator is required');
    final locator = ReaderLocator.decode(body['locator'] as String);
    if (locator == null ||
        !locator.compatible(item.id, revision) ||
        locator.page > count ||
        locator.pageKey != key(locator.page)) {
      await _json(r, 409, {
        'error': 'Content changed. Reopen the reader before saving.',
      });
      return;
    }
    if (p.length == 4 && p[3] == 'study') {
      final kind = body['kind'], id = body['id'], content = body['content'];
      if (!{'note', 'bookmark'}.contains(kind) ||
          id is! String ||
          !RegExp(r'^web-[a-zA-Z0-9-]{1,100}$').hasMatch(id) ||
          content is! String ||
          content.trim().isEmpty ||
          content.length > 16000)
        throw const FormatException('Invalid reader Study entry');
      final range = body['textRange'] == null
          ? null
          : ReaderTextAnchor.decode(body['textRange']);
      if (body['textRange'] != null &&
          (range == null ||
              !range.compatible(item.id, revision) ||
              range.startPage != locator.page ||
              range.endPage > count ||
              range.startKey != key(range.startPage) ||
              range.endKey != key(range.endPage) ||
              range.unit !=
                  (item.itemType == 'pdf' ? 'pdfCharacter' : 'domUtf16')))
        throw const FormatException('Invalid passage anchor');
      if (range != null) {
        if (range.endPage != range.startPage)
          throw const FormatException(
            'Browser passage selection must stay in one page/section',
          );
        final full = pdf != null
            ? (await pdf.pages[locator.page - 1].loadStructuredText()).fullText
            : source == null
            ? ''
            : await publicationText(
                await source.archive.text(key(locator.page)),
              );
        if (range.endOffset > full.length ||
            range.endOffset - range.startOffset > 16000 ||
            range.quote.isEmpty ||
            (pdf != null
                ? full.substring(range.startOffset, range.endOffset) !=
                      range.quote
                : !full.contains(range.quote)))
          throw const FormatException(
            'The selected passage no longer matches this page. Select it again.',
          );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.transaction(() async {
        final table = kind == 'note' ? 'notes' : 'bookmarks';
        final old = await db
            .customSelect(
              'SELECT item_id,library_id FROM $table WHERE id=?',
              variables: [d.Variable(id)],
            )
            .getSingleOrNull();
        if (old != null) {
          if (old.data['item_id'] != item.id ||
              old.data['library_id'] != item.libraryId)
            throw const FormatException('Study ownership cannot change');
          return;
        }
        await SyncSnapshotMerger(db).merge({
          'schemaVersion': 3,
          kind == 'note' ? 'notes' : 'bookmarks': [
            {
              'id': id,
              'libraryId': item.libraryId,
              'itemId': item.id,
              if (kind == 'note') 'content': content,
              if (kind == 'bookmark') 'title': content,
              'description': null,
              'positionSeconds': null,
              'pageNumber': locator.page,
              'createdAt': now,
              'updatedAt': now,
              'deviceId': device.id,
              'version': 1,
              'deleted': false,
            },
          ],
        }, allowedLibraryIds: mutate);
        await db.customStatement(
          'INSERT INTO study_anchors(id,library_id,item_id,note_id,bookmark_id,payload,updated_at) VALUES(?,?,?,?,?,?,?)',
          [
            '$kind:$id',
            item.libraryId,
            item.id,
            kind == 'note' ? id : null,
            kind == 'bookmark' ? id : null,
            jsonEncode({
              'kind': range == null ? 'page' : 'textRange',
              'locator': locator.encode(),
              if (range != null) 'textRange': range.toJson(),
            }),
            now,
          ],
        );
      });
      await _json(r, 200, {'status': 'saved'});
      return;
    }
    if (body['intent'] != null && body['intent'] != 'position')
      throw const FormatException('Invalid reader position intent');
    final changes = body['changes'];
    if (changes != null &&
        (changes is! Map ||
            changes.keys.any((k) => !{'fontSize', 'rtl'}.contains(k))))
      throw const FormatException('Unsupported browser reader preference');
    Map<String, dynamic>? result;
    await db.transaction(() async {
      final current = await catalog.record('reader:${item.id}'),
          old = await db.getReadingByItemId(item.id);
      if (body['version'] != (old?.version ?? 0) ||
          body['updatedAt'] != (current?.updatedAt ?? 0)) {
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch,
          done = old?.manualCompletion ?? old?.completed ?? false;
      await db.upsertReading(
        ReadingProgressCompanion(
          itemId: d.Value(item.id),
          lastPage: d.Value(locator.page),
          resumePage: d.Value(locator.page),
          lastScrollOffset: d.Value(0),
          resumeScrollOffset: d.Value(0),
          percentRead: d.Value(
            max(
              old?.percentRead ?? 0,
              (locator.page - 1) / count * 100,
            ).toDouble(),
          ),
          completed: d.Value(done),
          manualCompletion: d.Value(old?.manualCompletion),
          zoom: d.Value(locator.zoom),
          readingMode: d.Value(locator.fit),
          lastOpenedAt: d.Value(now),
          lastEventAt: d.Value(max(now, (old?.lastEventAt ?? 0) + 1)),
          deviceId: d.Value(device.id),
          version: d.Value((old?.version ?? 0) + 1),
        ),
        intent: body['intent'] == 'position' ? 'position' : null,
      );
      await catalog.save(
        'reader:${item.id}',
        'reader',
        item.libraryId,
        {
          ...?current?.data,
          if (changes is Map) ...Map<String, dynamic>.from(changes),
          'locator': locator.encode(),
        },
        itemId: item.id,
        changedFields: {
          'locator',
          if (changes is Map) ...changes.keys.cast<String>(),
        },
      );
      result = {
        'version': (await db.getReadingByItemId(item.id))!.version,
        'context': await SyncStateStore(db).context('reading', item.id),
        'updatedAt': (await catalog.record('reader:${item.id}'))!.updatedAt,
      };
    });
    if (result == null) {
      await _json(r, 409, {
        'error':
            'A newer reading position exists. Reopen it or explicitly retry your browser position.',
      });
    } else {
      await _json(r, 200, result!);
    }
  }

  Future<void> _publication(
    HttpRequest r,
    Item item,
    ArchiveBookSource source,
    String path,
  ) async {
    final pageRequest = r.uri.pathSegments[1] == 'reader';
    final name = SafeBookArchive.normalizeName(path),
        ext = name.split('.').last.toLowerCase();
    const types = {
      'xhtml': 'text/html',
      'html': 'text/html',
      'htm': 'text/html',
      'svg': 'image/svg+xml',
      'css': 'text/css',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'woff': 'font/woff',
      'woff2': 'font/woff2',
      'ttf': 'font/ttf',
      'otf': 'font/otf',
    };
    if (!types.containsKey(ext))
      throw const FormatException('Unsupported publication resource');
    var bytes = await source.archive.read(
      name,
      limit: ext == 'css' || types[ext] == 'text/html' || ext == 'svg'
          ? 2 * 1024 * 1024
          : 16 * 1024 * 1024,
    );
    if ((r.uri.queryParameters['request']?.length ?? 0) > 128)
      throw const FormatException(
        'Publication request identity exceeds the limit',
      );
    final prefix = '/v2/publication/${Uri.encodeComponent(item.id)}/';
    String address(String from, String href) {
      if (href.startsWith('#')) return href;
      final uri = Uri.parse(href);
      return prefix +
          PublicationServer.resolve(
            from,
            href,
          ).split('/').map(Uri.encodeComponent).join('/') +
          (uri.hasFragment ? '#${Uri.encodeComponent(uri.fragment)}' : '');
    }

    String css(String value) => value
        .replaceAllMapped(
          RegExp(
            r'''url\(\s*['"]?([^'"\)]+)['"]?\s*\)''',
            caseSensitive: false,
          ),
          (m) {
            try {
              return 'url("${address(name, m[1]!.trim())}")';
            } catch (_) {
              return 'url("")';
            }
          },
        )
        .replaceAllMapped(
          RegExp(r'''@import\s+['"]([^'"]+)['"]''', caseSensitive: false),
          (m) {
            try {
              return '@import "${address(name, m[1]!)}"';
            } catch (_) {
              return '';
            }
          },
        );
    if (types[ext] == 'text/html' || ext == 'svg') {
      final xml = publicationDocument(utf8.decode(bytes));
      for (final node in xml.descendants.whereType<XmlElement>().toList()) {
        if ({
              'script',
              'iframe',
              'object',
              'embed',
              'base',
              'form',
              'foreignobject',
            }.contains(node.name.local.toLowerCase()) ||
            node.name.local.toLowerCase() == 'meta' &&
                node.attributes.any(
                  (a) => a.name.local.toLowerCase() == 'http-equiv',
                )) {
          node.parent?.children.remove(node);
          continue;
        }
        node.attributes.removeWhere(
          (a) =>
              a.name.local.toLowerCase().startsWith('on') ||
              {
                'srcset',
                'srcdoc',
                'ping',
                'download',
                'target',
                'nonce',
              }.contains(a.name.local.toLowerCase()),
        );
        for (final a in node.attributes.toList()) {
          if ({'src', 'href', 'poster'}.contains(a.name.local.toLowerCase())) {
            try {
              a.value = address(name, a.value);
            } catch (_) {
              node.attributes.remove(a);
            }
          }
          if (a.name.local.toLowerCase() == 'style') a.value = css(a.value);
        }
        if (node.name.local.toLowerCase() == 'style') {
          final text = css(node.innerText);
          node.children
            ..clear()
            ..add(XmlText(text));
        }
      }
      if (ext == 'svg' && !pageRequest) {
        bytes = utf8.encode(xml.toXmlString());
        r.response.headers.set('Content-Type', 'image/svg+xml');
        r.response.headers.set(
          'Content-Security-Policy',
          "sandbox; default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:",
        );
        r.response.headers.contentLength = bytes.length;
        if (r.method != 'HEAD') r.response.add(bytes);
        await r.response.close();
        return;
      }
      final nonce = base64UrlEncode(
        List.generate(24, (_) => Random.secure().nextInt(256)),
      );
      final config = jsonEncode({
        'item': item.id,
        'key': name,
        'prefix': prefix,
        'request': r.uri.queryParameters['request'] ?? '',
        'revision': await CatalogIdentityStore(db).contentRevision(item),
      });
      final markup = xml.toXmlString();
      final script =
          '<script nonce="$nonce" src="/reader.js" data-config="${const HtmlEscape(HtmlEscapeMode.attribute).convert(config)}"></script>';
      var html = ext == 'svg'
          ? '<html><head></head><body>$markup</body></html>'
          : markup;
      html = html.replaceFirstMapped(
        RegExp(r'<body([^>]*)/\s*>', caseSensitive: false),
        (m) => '<body${m[1]}></body>',
      );
      if (!RegExp('</body>', caseSensitive: false).hasMatch(html))
        throw const FormatException(
          'Publication section requires an HTML body',
        );
      html = html.replaceFirst(
        RegExp('</body>', caseSensitive: false),
        '$script</body>',
      );
      r.response.headers.set(
        'Content-Security-Policy',
        "default-src 'none'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; font-src 'self'; script-src 'nonce-$nonce'; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'self'",
      );
      bytes = utf8.encode(html);
      r.response.headers.set('Content-Type', 'text/html; charset=utf-8');
    } else if (ext == 'css') {
      bytes = utf8.encode(css(utf8.decode(bytes)));
      r.response.headers.set('Content-Type', 'text/css; charset=utf-8');
    } else
      r.response.headers.set('Content-Type', types[ext]!);
    r.response.headers.set('Referrer-Policy', 'no-referrer');
    r.response.headers.contentLength = bytes.length;
    if (r.method != 'HEAD') r.response.add(bytes);
    await r.response.close();
  }
}
