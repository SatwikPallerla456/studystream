import 'dart:convert';
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../../domain/services/sync_intent.dart';
import '../../domain/services/sync_conflict_resolver.dart';
import '../../domain/catalog/media_record_contract.dart';

class ProgressContextChanged implements Exception {
  const ProgressContextChanged();
  @override
  String toString() =>
      'Progress changed on another player. Reopen this title before saving a new position.';
}

/// Additive envelopes share each existing row's identity and journal event. No
/// source path or credential is introduced into sync/backup payloads.
class SyncStateStore {
  const SyncStateStore(this.db);
  final AppDatabase db;
  Future<void> createTables() async {
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS sync_progress_state(id TEXT PRIMARY KEY,item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,kind TEXT NOT NULL,payload TEXT NOT NULL)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_progress_item ON sync_progress_state(item_id,kind)',
    );
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS sync_preference_state(id TEXT PRIMARY KEY REFERENCES media_records(id) ON DELETE CASCADE,payload TEXT NOT NULL)',
    );
  }

  Future<Map<String, dynamic>?> row(String kind, String itemId) async =>
      kind == 'playback'
      ? (await db.getPlaybackByItemId(itemId))?.toJson()
      : (await db.getReadingByItemId(itemId))?.toJson();
  Future<Map<String, dynamic>> decorate(
    String kind,
    Map<String, dynamic> value,
  ) async {
    final saved = await db
        .customSelect(
          'SELECT payload FROM sync_progress_state WHERE id=?',
          variables: [d.Variable('$kind:${value['itemId']}')],
        )
        .getSingleOrNull();
    return {
      ...value,
      if (saved != null)
        'syncProgress': jsonDecode(saved.data['payload'] as String),
    };
  }

  Future<Map<String, dynamic>> context(String kind, String itemId) =>
      db.transaction(
        () async => SyncIntent.state(
          await decorate(kind, await row(kind, itemId) ?? {'itemId': itemId}),
        ),
      );
  Future<void> requireContext(
    String kind,
    String itemId,
    Map<String, dynamic> expected,
  ) async {
    if (!SyncIntent.samePositionContext(await context(kind, itemId), expected))
      throw const ProgressContextChanged();
  }

  Future<bool> local(
    String kind,
    Map<String, dynamic> value, {
    Map<String, dynamic>? expected,
    String? intent,
    bool? completion,
    bool clearCompletion = false,
    String? author,
  }) => db.transaction(() async {
    final itemId = value['itemId'] as String, old = await row(kind, itemId);
    final existing = old == null
        ? <String, dynamic>{
            ...value,
            'completed': false,
            'manualCompletion': null,
          }
        : await decorate(kind, old);
    final state = SyncIntent.state(existing);
    if (expected != null &&
        (!SyncIntent.equal(state['epoch'], expected['epoch']) ||
            !SyncIntent.samePositionContext(state, expected) && intent == null))
      throw const ProgressContextChanged();
    final clock = SyncIntent.maximum(state) + 1;
    if (clock >= SyncIntent.maxClock)
      throw const FormatException('Progress revision exhausted');
    final stamp = [
      clock,
      author ?? value['deviceId'] ?? await db.getDeviceId(),
      const Uuid().v4(),
    ];
    final next = {...state, 'sample': stamp};
    if (intent == 'reset') {
      next['epoch'] = stamp;
      next['position'] = stamp;
      next['completion'] = stamp;
      next['policy'] = null;
      next['auto'] = false;
    }
    if (intent == 'position') next['position'] = stamp;
    if (completion != null || clearCompletion) {
      next['completion'] = stamp;
      next['policy'] = completion;
      next['auto'] = false;
    }
    if (intent != 'reset' && completion == null && !clearCompletion)
      next['auto'] =
          value['completed'] == true && value['manualCompletion'] == null;
    final candidate = {
      ...value,
      'syncProgress': next,
      'manualCompletion': next['policy'],
      'completed': (next['policy'] as bool?) ?? next['auto'],
    };
    final merged = intent == 'reset'
        ? candidate
        : SyncIntent.merge(existing, candidate);
    return _publish(kind, merged);
  });
  Future<void> merge(String kind, Map<String, dynamic> remote) =>
      db.transaction(() async {
        if (remote['syncProgress'] != null) SyncIntent.state(remote);
        final old = await row(kind, remote['itemId'] as String);
        final local = old == null ? null : await decorate(kind, old);
        final normalized = remote['syncProgress'] == null
            ? remote
            : SyncIntent.merge(remote, remote);
        final result = local == null
            ? normalized
            : SyncConflictResolver.mergeProgress(local, normalized);
        await _publish(kind, result);
      });
  Future<bool> _publish(String kind, Map<String, dynamic> value) async {
    final itemId = value['itemId'] as String,
        old = await row(kind, itemId),
        before = old == null ? null : await decorate(kind, old);
    Map<String, dynamic> semantic(Map<String, dynamic> v) =>
        {...v}..remove('version');
    if (before != null &&
        SyncIntent.canonical(semantic(before)) ==
            SyncIntent.canonical(semantic(value)))
      return false;
    final next = {
      ...value,
      'version': old == null
          ? (value['version'] as num? ?? 1).toInt()
          : (old['version'] as int) + 1,
    };
    if (kind == 'playback') {
      await db
          .into(db.playbackProgress)
          .insertOnConflictUpdate(PlaybackProgressData.fromJson(next));
    } else {
      await db
          .into(db.readingProgress)
          .insertOnConflictUpdate(ReadingProgressData.fromJson(next));
    }
    if (value['syncProgress'] != null)
      await db.customStatement(
        'INSERT INTO sync_progress_state(id,item_id,kind,payload) VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
        ['$kind:$itemId', itemId, kind, jsonEncode(value['syncProgress'])],
      );
    return true;
  }

  bool fielded(String kind) =>
      {'reader', 'library', 'organization', 'music'}.contains(kind);
  Future<Map<String, dynamic>> decorateFields(Map<String, dynamic> row) async {
    if (!fielded(row['kind'] as String)) return row;
    final value = await db
        .customSelect(
          'SELECT payload FROM sync_preference_state WHERE id=?',
          variables: [d.Variable(row['id'] as String)],
        )
        .getSingleOrNull();
    return {
      ...row,
      if (value != null)
        'fieldState': jsonDecode(value.data['payload'] as String),
    };
  }

  Map<String, dynamic> _fields(Map<String, dynamic> row) {
    final raw = row['fieldState'],
        data = jsonDecode(row['payload'] as String) as Map;
    if (raw != null) {
      if (raw is! Map || raw['v'] != 1 || raw['fields'] is! Map)
        throw const FormatException('Invalid preference revisions');
      final fields = Map<String, dynamic>.from(raw['fields'] as Map);
      if (fields.length > 40)
        throw const FormatException('Too many preference revisions');
      final allowed = MediaRecordContract.fields(row['kind'] as String)!;
      for (final e in fields.entries) {
        if (!allowed.contains(e.key) ||
            e.value is! Map ||
            e.value['removed'] is! bool)
          throw const FormatException('Invalid preference field');
        SyncIntent.stamp(e.value['stamp']);
        if (e.value['progress'] != null) {
          if (e.key != 'locator' || e.value['progress'] is! Map)
            throw const FormatException('Invalid locator context');
          SyncIntent.stamp(e.value['progress']['epoch']);
          SyncIntent.stamp(e.value['progress']['position']);
        }
      }
      return fields;
    }
    return {
      for (final k in data.keys)
        k: {
          'stamp': [
            (row['updated_at'] as int).clamp(0, SyncIntent.maxClock - 1),
            row['device_id'],
            'legacy',
          ],
          'removed': false,
        },
    };
  }

  Future<Map<String, dynamic>> localFields(
    Map<String, dynamic> incoming,
    Map<String, dynamic>? existing, {
    Set<String>? changed,
  }) async {
    if (!fielded(incoming['kind'] as String)) return incoming;
    final data = Map<String, dynamic>.from(
      jsonDecode(incoming['payload'] as String) as Map,
    );
    final before = existing == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(existing['payload'] as String) as Map,
          );
    final fields = existing == null
        ? <String, dynamic>{}
        : _fields(await decorateFields(existing));
    final edits =
        changed ??
        {...before.keys, ...data.keys}
            .where(
              (k) =>
                  SyncIntent.canonical(before[k]) !=
                      SyncIntent.canonical(data[k]) ||
                  before.containsKey(k) != data.containsKey(k),
            )
            .toSet();
    var clock =
        fields.values.fold<int>(0, (n, v) {
          final c = SyncIntent.stamp(v['stamp'])[0] as int;
          return c > n ? c : n;
        }) +
        1;
    if (clock >= SyncIntent.maxClock)
      throw const FormatException('Preference revision exhausted');
    final stamp = [clock, incoming['device_id'], const Uuid().v4()];
    final next = {...before};
    for (final key in edits) {
      if (!MediaRecordContract.fields(
        incoming['kind'] as String,
      )!.contains(key))
        throw const FormatException('Unknown preference field');
      if (data.containsKey(key)) {
        next[key] = data[key];
      } else {
        next.remove(key);
      }
      fields[key] = {
        'stamp': stamp,
        'removed': !data.containsKey(key),
        if (key == 'locator' && incoming['item_id'] is String)
          'progress': await context('reading', incoming['item_id'] as String),
      };
    }
    return {
      ...incoming,
      'payload': jsonEncode(next),
      'fieldState': {'v': 1, 'fields': fields},
    };
  }

  Future<Map<String, dynamic>> mergeFields(
    Map<String, dynamic> incoming,
    Map<String, dynamic>? old,
  ) async {
    if (!fielded(incoming['kind'] as String)) return incoming;
    if (old == null) {
      // Even first-time locator imports must agree with the progress epoch.
      final fields = _fields(incoming);
      final data = Map<String, dynamic>.from(
        jsonDecode(incoming['payload'] as String) as Map,
      );
      final locator = fields['locator'];
      if (locator != null && incoming['item_id'] is String) {
        final ctx = await context('reading', incoming['item_id'] as String);
        if (locator['progress'] == null
            ? SyncIntent.fenced(ctx)
            : !SyncIntent.samePositionContext(
                ctx,
                Map<String, dynamic>.from(locator['progress'] as Map),
              )) {
          fields.remove('locator');
          data.remove('locator');
        }
      }
      return {
        ...incoming,
        'payload': jsonEncode(data),
        'fieldState': {'v': 1, 'fields': fields},
      };
    }
    final local = await decorateFields(old),
        a = _fields(local),
        b = _fields(incoming),
        left = jsonDecode(old['payload'] as String) as Map,
        right = jsonDecode(incoming['payload'] as String) as Map;
    // Whole-record deletion keeps its existing timestamp semantics. Preference
    // reset is a retained field tombstone, not deletion of this container.
    if (old['deleted'] != incoming['deleted'])
      return (old['updated_at'] as int) >= (incoming['updated_at'] as int)
          ? local
          : incoming;
    final data = <String, dynamic>{}, fields = <String, dynamic>{};
    for (final key in {...a.keys, ...b.keys}) {
      final x = a[key], y = b[key];
      var takeRemote =
          x == null ||
          y != null && SyncIntent.compare(x['stamp'], y['stamp']) < 0;
      if (x != null &&
          y != null &&
          SyncIntent.stamp(x['stamp'])[2] == 'legacy' &&
          SyncIntent.stamp(y['stamp'])[2] != 'legacy')
        takeRemote = true;
      if (x != null &&
          SyncIntent.stamp(x['stamp'])[2] != 'legacy' &&
          y != null &&
          SyncIntent.stamp(y['stamp'])[2] == 'legacy')
        takeRemote = false;
      if (x != null && y != null && SyncIntent.equal(x['stamp'], y['stamp'])) {
        takeRemote =
            SyncIntent.canonical({'entry': y, 'value': right[key]}).compareTo(
              SyncIntent.canonical({'entry': x, 'value': left[key]}),
            ) >
            0;
      }
      if (key == 'locator' && y != null && incoming['item_id'] is String) {
        final ctx = await context('reading', incoming['item_id'] as String);
        if (y['progress'] == null
            ? SyncIntent.fenced(ctx)
            : !SyncIntent.samePositionContext(
                ctx,
                Map<String, dynamic>.from(y['progress'] as Map),
              ))
          takeRemote = false;
      }
      final winner = takeRemote ? y : x;
      if (winner == null) continue;
      fields[key] = winner;
      if (winner['removed'] != true) {
        final values = takeRemote ? right : left;
        if (values.containsKey(key)) data[key] = values[key];
      }
    }
    final timestamp =
        (incoming['updated_at'] as int) > (old['updated_at'] as int)
        ? incoming['updated_at']
        : old['updated_at'];
    return {
      ...incoming,
      'payload': jsonEncode(data),
      'updated_at': timestamp,
      'fieldState': {'v': 1, 'fields': fields},
    };
  }

  Future<void> publishFields(Map<String, dynamic> row) async {
    if (row['fieldState'] == null) return;
    final old = await db
        .customSelect(
          'SELECT payload FROM sync_preference_state WHERE id=?',
          variables: [d.Variable(row['id'] as String)],
        )
        .getSingleOrNull();
    final changed =
        old == null ||
        SyncIntent.canonical(jsonDecode(old.data['payload'] as String)) !=
            SyncIntent.canonical(row['fieldState']);
    await db.customStatement(
      'INSERT INTO sync_preference_state(id,payload) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
      [row['id'], jsonEncode(row['fieldState'])],
    );
    if (changed)
      await db.customStatement(
        'INSERT INTO sync_change_journal(library_id,entity_kind,entity_id,deleted,recorded_at) VALUES(?,?,?,?,?)',
        [
          row['library_id'],
          'media_records',
          row['id'],
          row['deleted'],
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
  }
}
