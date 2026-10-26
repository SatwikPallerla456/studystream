import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/db/app_database.dart';
import '../catalog/catalog_identity_store.dart';
import '../catalog/media_catalog_repository.dart';
import 'music_models.dart';

class MusicRepository {
  const MusicRepository(this.db);
  final AppDatabase db;
  static String facet(String field) =>
      "COALESCE((SELECT value FROM catalog_facets f WHERE f.item_id=i.id AND f.field='$field'),'')";
  ({String sql, List<Variable> args}) where(MusicRules rules) {
    MusicRules.fromJson(rules.toJson());
    final clauses = <String>[
          "i.item_type='audio'",
          "i.unavailable=0",
          "EXISTS(SELECT 1 FROM catalog_facets c WHERE c.item_id=i.id AND c.field='category' AND c.value='music')",
        ],
        args = <Variable>[];
    if (rules.libraryId != null) {
      clauses.add('i.library_id=?');
      args.add(Variable(rules.libraryId!));
    }
    for (final entry in {
      'artist': rules.artist,
      'album': rules.album,
    }.entries) {
      if (entry.value.isNotEmpty) {
        clauses.add('${facet(entry.key)}=?');
        args.add(Variable(entry.value));
      }
    }
    if (rules.genre.isNotEmpty) {
      clauses.add("instr(lower(${facet('genres')}),lower(?))>0");
      args.add(Variable(rules.genre));
    }
    if (rules.tag.isNotEmpty) {
      clauses.add(
        "EXISTS(SELECT 1 FROM media_records m,json_each(m.payload,'\$.tags') t WHERE m.item_id=i.id AND m.kind='organization' AND m.deleted=0 AND lower(t.value)=lower(?))",
      );
      args.add(Variable(rules.tag));
    }
    if (rules.favorite)
      clauses.add(
        "EXISTS(SELECT 1 FROM media_records m WHERE m.item_id=i.id AND m.kind='organization' AND m.deleted=0 AND json_extract(m.payload,'\$.favorite')=1)",
      );
    if (rules.unplayed)
      clauses.add(
        "NOT EXISTS(SELECT 1 FROM app_settings s WHERE s.key='music.stats:'||i.id AND COALESCE(json_extract(s.value,'\$.plays'),0)>0)",
      );
    if (rules.minYear > 0 || rules.maxYear < 9999) {
      clauses.add("CAST(${facet('year')} AS INTEGER) BETWEEN ? AND ?");
      args.addAll([Variable(rules.minYear), Variable(rules.maxYear)]);
    }
    if (rules.minSeconds > 0 || rules.maxSeconds < 315360000) {
      clauses.add('COALESCE(i.duration_seconds,0) BETWEEN ? AND ?');
      args.addAll([Variable(rules.minSeconds), Variable(rules.maxSeconds)]);
    }
    return (sql: clauses.map((s) => '($s)').join(' AND '), args: args);
  }

  Future<List<Item>> candidates(
    MusicRules rules, {
    String after = '',
    int? limit,
    bool idOrder = false,
  }) async {
    final w = where(rules);
    final order = idOrder
        ? 'i.id'
        : switch (rules.order) {
            'random' => 'RANDOM()',
            'recent' =>
              "COALESCE((SELECT json_extract(s.value,'\$.lastPlayed') FROM app_settings s WHERE s.key='music.stats:'||i.id),0) DESC",
            'leastPlayed' =>
              "COALESCE((SELECT json_extract(s.value,'\$.plays') FROM app_settings s WHERE s.key='music.stats:'||i.id),0),lower(i.title)",
            _ => "lower(COALESCE(i.user_title,i.title)),i.id",
          };
    final rows = await db
        .customSelect(
          'SELECT i.* FROM items i WHERE ${w.sql} ${after.isEmpty ? '' : 'AND i.id>?'} ORDER BY $order LIMIT ?',
          variables: [
            ...w.args,
            if (after.isNotEmpty) Variable(after),
            Variable((limit ?? rules.limit).clamp(1, 512)),
          ],
        )
        .get();
    return rows.map((r) => db.items.map(r.data)).toList();
  }

  Future<int> count(MusicRules rules) async {
    final w = where(rules);
    return (await db
                .customSelect(
                  'SELECT COUNT(*) AS total FROM items i WHERE ${w.sql}',
                  variables: w.args,
                )
                .getSingle())
            .data['total']
        as int;
  }

  Future<List<Map<String, dynamic>>> settings(
    String prefix, {
    String? before,
    int limit = 64,
  }) async =>
      (await db
              .customSelect(
                'SELECT key,value FROM app_settings WHERE key>=? AND key<? ${before == null ? '' : 'AND key<?'} ORDER BY key DESC LIMIT ?',
                variables: [
                  Variable(prefix),
                  Variable('${prefix.substring(0, prefix.length - 1)};'),
                  if (before != null) Variable(before),
                  Variable(limit.clamp(1, 100)),
                ],
              )
              .get())
          .map(
            (r) => <String, dynamic>{
              ...Map<String, dynamic>.from(
                jsonDecode(r.data['value'] as String) as Map,
              ),
              'key': r.data['key'],
            },
          )
          .toList();
  Future<void> _capacity(String prefix, String id) async {
    if (await db.getSetting('$prefix$id') != null) return;
    final count =
        (await db
                    .customSelect(
                      'SELECT COUNT(*) AS total FROM app_settings WHERE key>=? AND key<?',
                      variables: [
                        Variable(prefix),
                        Variable('${prefix.substring(0, prefix.length - 1)};'),
                      ],
                    )
                    .getSingle())
                .data['total']
            as int;
    if (count >= 64)
      throw const FormatException(
        'Keep at most 64 saved entries. Remove an unused one first.',
      );
  }

  Future<void> saveSmart(String title, MusicRules rules, {String? id}) async {
    if (title.trim().isEmpty || title.length > 200)
      throw const FormatException('Enter a playlist name');
    MusicRules.fromJson(rules.toJson());
    final key = id ?? const Uuid().v4();
    await _capacity('music.smart:', key);
    await db.setSetting(
      'music.smart:$key',
      jsonEncode({'id': key, 'title': title.trim(), 'rules': rules.toJson()}),
    );
  }

  Future<void> deleteSetting(String key) async {
    if (!key.startsWith('music.smart:') && !key.startsWith('music.output:'))
      throw const FormatException('Invalid music setting');
    await (db.delete(db.appSettings)..where((t) => t.key.equals(key))).go();
  }

  Future<void> saveProfile(AudioOutputProfile profile) async {
    AudioOutputProfile.fromJson(profile.toJson());
    await _capacity('music.output:', profile.id);
    await db.setSetting(
      'music.output:${profile.id}',
      jsonEncode(profile.toJson()),
    );
  }

  Future<void> checkpointListen({
    required String sessionId,
    required Item item,
    required String title,
    required String artist,
    required double listened,
    required bool completed,
    required int startedAt,
    required bool skipped,
  }) => db.transaction(() async {
    if (!listened.isFinite || listened < 0 || listened > 315360000)
      throw const FormatException('Invalid listening time');
    final key =
        'music.history:${startedAt.toString().padLeft(16, '0')}:$sessionId';
    final oldRaw = await db.getSetting(key),
        old = oldRaw == null ? <String, dynamic>{} : jsonDecode(oldRaw) as Map;
    final qualified =
        listened >= 30 ||
        completed && listened >= min(10.0, (item.durationSeconds ?? 10) / 2);
    final counted = old['counted'] == true;
    await db.setSetting(
      key,
      jsonEncode({
        'sessionId': sessionId,
        'itemId': item.id,
        'libraryId': item.libraryId,
        'title': title,
        'artist': artist,
        'startedAt': startedAt,
        'listened': listened,
        'completed': completed,
        'skipped': skipped,
        'counted': qualified || counted,
      }),
    );
    if (qualified && !counted) {
      final raw = await db.getSetting('music.stats:${item.id}'),
          stats = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map;
      await db.setSetting(
        'music.stats:${item.id}',
        jsonEncode({
          'plays': (stats['plays'] as int? ?? 0) + 1,
          'lastPlayed': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    }
    await db.customStatement(
      "DELETE FROM app_settings WHERE key IN (SELECT key FROM app_settings WHERE key>='music.history:' AND key<'music.history;' ORDER BY key DESC LIMIT -1 OFFSET 5000)",
    );
  });
  Future<void> clearHistory() async {
    await db.customStatement(
      "DELETE FROM app_settings WHERE (key>='music.history:' AND key<'music.history;') OR (key>='music.stats:' AND key<'music.stats;')",
    );
  }

  Future<List<Item>> radio(
    MusicRules rules, {
    int count = 50,
    bool variety = true,
    int avoidHours = 24,
    Set<String> exclude = const {},
  }) async {
    final pool = await candidates(
      MusicRules.fromJson({...rules.toJson(), 'order': 'random', 'limit': 500}),
      limit: 512,
    );
    final output = <Item>[], recentArtists = <String>[];
    final catalog = MediaCatalogRepository(db),
        cutoff = DateTime.now()
            .subtract(Duration(hours: avoidHours.clamp(0, 720)))
            .millisecondsSinceEpoch;
    for (final item in pool) {
      if (exclude.contains(item.id)) continue;
      final raw = await db.getSetting('music.stats:${item.id}');
      if (raw != null &&
          ((jsonDecode(raw) as Map)['lastPlayed'] as int? ?? 0) > cutoff)
        continue;
      final artist = (await catalog.metadata(item))['artist'] as String? ?? '';
      if (variety && artist.isNotEmpty && recentArtists.contains(artist))
        continue;
      output.add(item);
      recentArtists.add(artist);
      if (recentArtists.length > 3) recentArtists.removeAt(0);
      if (output.length >= count.clamp(1, 200)) break;
    }
    return output;
  }

  Future<Map<String, dynamic>> extras(Item item) async {
    final embedded = await db
        .customSelect(
          'SELECT payload FROM embedded_tags WHERE item_id=? AND content_revision=?',
          variables: [
            Variable(item.id),
            Variable(await CatalogIdentityStore(db).contentRevision(item)),
          ],
        )
        .getSingleOrNull();
    final tags = embedded == null
        ? <String, dynamic>{}
        : jsonDecode(embedded.data['payload'] as String) as Map;
    final record = await MediaCatalogRepository(db).record('music:${item.id}');
    final raw = await db
        .customSelect(
          'SELECT payload FROM sync_preference_state WHERE id=?',
          variables: [Variable('music:${item.id}')],
        )
        .getSingleOrNull();
    final fields = raw == null
        ? <String, dynamic>{}
        : (jsonDecode(raw.data['payload'] as String) as Map)['fields'] as Map;
    return {
      for (final key in ['lyrics', 'lrc'])
        if (tags[key] is String && fields[key]?['removed'] != true)
          key: tags[key],
      ...?record?.data,
    };
  }

  Future<void> saveExtras(
    Item item,
    Map<String, dynamic> edits, {
    Set<String> reset = const {},
  }) async {
    final catalog = MediaCatalogRepository(db),
        data = {...await extras(item), ...edits};
    for (final key in reset) {
      data.remove(key);
    }
    if (data['lrc'] is String) LyricLine.parse(data['lrc'] as String);
    if (data['cue'] is String) CueTrack.decode(data['cue'] as String);
    await catalog.save(
      'music:${item.id}',
      'music',
      item.libraryId,
      data,
      itemId: item.id,
      changedFields: {...edits.keys, ...reset},
    );
  }

  /// Snapshot target IDs on disk before confirmation; concurrent scans cannot
  /// quietly expand a confirmed bulk scope. No catalog-sized Dart collection.
  Future<(String, int)> prepareBulk(
    MusicRules rules,
  ) => db.transaction(() async {
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS music_bulk_targets(job TEXT NOT NULL,item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,created_at INTEGER NOT NULL,PRIMARY KEY(job,item_id))',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      'DELETE FROM music_bulk_targets WHERE created_at<?',
      [now - 86400000],
    );
    final job = const Uuid().v4(), w = where(rules);
    await db.customInsert(
      'INSERT INTO music_bulk_targets(job,item_id,created_at) SELECT ?,i.id,? FROM items i WHERE ${w.sql}',
      variables: [Variable(job), Variable(now), ...w.args],
    );
    final count =
        (await db
                    .customSelect(
                      'SELECT COUNT(*) AS total FROM music_bulk_targets WHERE job=?',
                      variables: [Variable(job)],
                    )
                    .getSingle())
                .data['total']
            as int;
    return (job, count);
  });
  Future<void> releaseBulk(String job) =>
      db.customStatement('DELETE FROM music_bulk_targets WHERE job=?', [job]);
  Future<void> bulkTags(
    MusicRules rules, {
    required String field,
    required String value,
    required String mode,
    required String job,
    required bool Function() cancelled,
    required void Function(int) progress,
  }) async {
    if (!{
          'tags',
          'artist',
          'album',
          'albumArtist',
          'composer',
          'genres',
          'year',
          'credits',
          'label',
        }.contains(field) ||
        !{'replace', 'add', 'remove', 'reset'}.contains(mode) ||
        value.length > 16000)
      throw const FormatException('Invalid music tag edit');
    if (field != 'tags' && {'add', 'remove'}.contains(mode))
      throw const FormatException('Add/remove apply to organization tags');
    if (field == 'year' &&
        mode != 'reset' &&
        (int.tryParse(value) == null ||
            int.parse(value) < 0 ||
            int.parse(value) > 9999))
      throw const FormatException('Enter a year from 0–9999');
    var after = '', done = 0;
    try {
      while (!cancelled()) {
        final rows = await db
            .customSelect(
              'SELECT i.* FROM music_bulk_targets t JOIN items i ON i.id=t.item_id WHERE t.job=? AND t.item_id>? ORDER BY t.item_id LIMIT 100',
              variables: [Variable(job), Variable(after)],
            )
            .get();
        final page = rows.map((r) => db.items.map(r.data)).toList();
        if (page.isEmpty) break;
        await db.transaction(() async {
          for (final item in page) {
            if (cancelled()) break;
            if (field == 'tags') {
              final old =
                  (await MediaCatalogRepository(
                        db,
                      ).record('organization:${item.id}'))?.data['tags']
                      as List? ??
                  [];
              final incoming = value
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList(),
                  keys = value
                      .split(',')
                      .map((s) => s.trim().toLowerCase())
                      .toSet();
              final tags = mode == 'reset'
                  ? <String>[]
                  : mode == 'add'
                  ? [...old.cast<String>(), ...incoming]
                  : mode == 'remove'
                  ? old
                        .cast<String>()
                        .where((s) => !keys.contains(s.toLowerCase()))
                        .toList()
                  : incoming;
              await MediaCatalogRepository(db).setTags(item, tags);
            } else {
              await CatalogIdentityStore(db).override(
                item,
                field,
                field == 'year' ? int.tryParse(value) : value,
                reset: mode == 'reset',
              );
            }
            progress(++done);
          }
        });
        after = page.last.id;
      }
    } finally {
      await releaseBulk(job);
    }
  }
}
