import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/utils/id_utils.dart';
import '../../data/db/app_database.dart';
import 'media_record_contract.dart';

/// Descriptive identities never replace Items or carry exact playback positions.
class CatalogIdentityStore {
  const CatalogIdentityStore(this.db);
  final AppDatabase db;
  static const tables={
    'catalog_works','provider_snapshots','match_decisions','catalog_overrides',
    'catalog_editions','playable_representations','media_parts','technical_media','catalog_memberships',
  };
  Future<void> createTables() async {
    const definitions={
      'catalog_works': 'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, type TEXT NOT NULL, title TEXT NOT NULL, parent_id TEXT, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'provider_snapshots': 'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, work_id TEXT NOT NULL REFERENCES catalog_works(id) ON DELETE CASCADE, provider_id TEXT NOT NULL, remote_id TEXT NOT NULL, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'match_decisions': 'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, item_id TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE, work_id TEXT REFERENCES catalog_works(id), state TEXT NOT NULL, provider_id TEXT, remote_id TEXT, revision INTEGER NOT NULL, origin TEXT NOT NULL, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'catalog_overrides': 'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE, field TEXT NOT NULL, value TEXT, removed INTEGER NOT NULL, locked INTEGER NOT NULL, revision INTEGER NOT NULL, updated_at INTEGER NOT NULL, UNIQUE(item_id,field)',
      'catalog_editions': 'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, work_id TEXT NOT NULL REFERENCES catalog_works(id) ON DELETE CASCADE, title TEXT NOT NULL, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'playable_representations': 'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, item_id TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE, edition_id TEXT NOT NULL REFERENCES catalog_editions(id) ON DELETE CASCADE, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'media_parts': 'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, representation_id TEXT NOT NULL REFERENCES playable_representations(id) ON DELETE CASCADE, item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE, position INTEGER NOT NULL, duration_seconds REAL, offset_seconds REAL, updated_at INTEGER NOT NULL',
      'technical_media': 'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, item_id TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE, content_revision TEXT NOT NULL, analysis_version INTEGER NOT NULL, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'catalog_memberships': 'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, collection_id TEXT NOT NULL, kind TEXT NOT NULL, item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE, position INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL',
    };
    for(final entry in definitions.entries) await db.customStatement('CREATE TABLE IF NOT EXISTS ${entry.key} (${entry.value})');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_catalog_work_library ON catalog_works(library_id,type,title,id)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_catalog_decision_item ON match_decisions(library_id,item_id,revision)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_catalog_members ON catalog_memberships(library_id,collection_id,position,item_id)');
    await db.customStatement('''CREATE VIRTUAL TABLE IF NOT EXISTS catalog_search USING fts5(item_id UNINDEXED,library_id UNINDEXED,title,creator,tags)''');
  }
  Future<void> backfill() async {
    final missing=await db.customSelect('SELECT i.id FROM items i LEFT JOIN playable_representations r ON r.item_id=i.id WHERE r.id IS NULL').get();
    for(final row in missing) {
      final item=(await db.getItemById(row.data['id'] as String))!;
      final hints=filenameHints(item.filename),now=DateTime.now().millisecondsSinceEpoch;
      final work='local:${item.id}',edition='edition:${item.id}';
      await db.customStatement('INSERT OR IGNORE INTO catalog_works(id,library_id,type,title,payload,updated_at) VALUES(?,?,?,?,?,?)',
        [work,item.libraryId,item.itemType=='audio'?'track':item.itemType=='video'?'movie':'book',item.title,'{}',now]);
      await db.customStatement('INSERT OR IGNORE INTO catalog_editions(id,library_id,work_id,title,payload,updated_at) VALUES(?,?,?,?,?,?)',
        [edition,item.libraryId,work,hints['edition']??'Original','{}',now]);
      await db.customStatement('INSERT OR IGNORE INTO playable_representations(id,library_id,item_id,edition_id,payload,updated_at) VALUES(?,?,?,?,?,?)',
        [item.id,item.libraryId,item.id,edition,jsonEncode(hints),now]);
      await db.customStatement('INSERT OR IGNORE INTO technical_media(id,library_id,item_id,content_revision,analysis_version,payload,updated_at) VALUES(?,?,?,?,?,?,?)',
        [item.id,item.libraryId,item.id,item.fingerprint??'legacy:${item.fileSize}:${item.modifiedAt}',1,jsonEncode({'durationSeconds':item.durationSeconds,'pageCount':item.pageCount,'container':item.filename.split('.').last,'analysisState':'indexed'}),now]);
      await reindex(item);
    }
  }
  Future<Map<String,dynamic>?> decision(String itemId) async =>
    (await db.customSelect('SELECT * FROM match_decisions WHERE item_id=?',variables:[Variable(itemId)]).getSingleOrNull())?.data;
  Future<int> _revision(String table,String id) async =>
    ((await db.customSelect('SELECT revision FROM $table WHERE id=?',variables:[Variable(id)]).getSingleOrNull())?.data['revision'] as int? ?? 0)+1;
  Future<void> _expected(String itemId,int? expected) async {
    final current=(await decision(itemId))?['revision'] as int? ?? 0;
    if(expected != null && current != expected) throw const FormatException('This match changed on another screen or device. Reload before saving.');
  }
  Future<void> select(Item item,Map<String,dynamic> candidate,{required String providerId,int? expectedRevision,String origin='user'}) => db.transaction(() async {
    await _expected(item.id,expectedRevision);
    final remoteId=candidate['id'];
    if(remoteId is! String || candidate['title'] is! String) throw const FormatException('A match needs an ID and title');
    MediaRecordContract.identity(providerId);MediaRecordContract.identity(remoteId);
    final safe=Map<String,dynamic>.from(candidate)..remove('id');
    MediaRecordContract.validate(id:'metadata:${item.id}',kind:'metadata',libraryId:item.libraryId,itemId:item.id,data:safe);
    final now=DateTime.now().millisecondsSinceEpoch;
    final work=stableId('${item.libraryId}:$providerId:$remoteId');
    final type=item.itemType=='audio'?'track':(safe['episode'] != null?'episode':item.itemType=='video'?'movie':'book');
    await db.customStatement('''INSERT INTO catalog_works(id,library_id,type,title,payload,updated_at) VALUES(?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET title=excluded.title,payload=excluded.payload,updated_at=excluded.updated_at''',[work,item.libraryId,type,safe['title'],jsonEncode(safe),now]);
    await db.customStatement('''INSERT INTO provider_snapshots(id,library_id,work_id,provider_id,remote_id,payload,updated_at) VALUES(?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated_at=excluded.updated_at''',[work,item.libraryId,work,providerId,remoteId,jsonEncode(safe),now]);
    final revision=await _revision('match_decisions',item.id);
    await db.customStatement('''INSERT INTO match_decisions(id,library_id,item_id,work_id,state,provider_id,remote_id,revision,origin,payload,updated_at)
      VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET work_id=excluded.work_id,state=excluded.state,provider_id=excluded.provider_id,
      remote_id=excluded.remote_id,revision=excluded.revision,origin=excluded.origin,payload=excluded.payload,updated_at=excluded.updated_at''',
      [item.id,item.libraryId,item.id,work,'matched',providerId,remoteId,revision,origin,jsonEncode({'provider':providerId,'candidate':remoteId,'selectedAt':now,'method':'explicit'}),now]);
    final hints=filenameHints(item.filename);
    final edition=stableId('$work:${hints['edition']??'Original'}');
    await db.customStatement('INSERT OR IGNORE INTO catalog_editions(id,library_id,work_id,title,payload,updated_at) VALUES(?,?,?,?,?,?)',[edition,item.libraryId,work,hints['edition']??'Original','{}',now]);
    await db.customStatement('''INSERT INTO playable_representations(id,library_id,item_id,edition_id,payload,updated_at) VALUES(?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET edition_id=excluded.edition_id,payload=excluded.payload,updated_at=excluded.updated_at''',[item.id,item.libraryId,item.id,edition,jsonEncode(hints),now]);
    await reindex(item);
  });
  Future<void> clear(Item item,{int? expectedRevision}) =>db.transaction(()async{
    await _expected(item.id,expectedRevision);
    final revision=await _revision('match_decisions',item.id), now=DateTime.now().millisecondsSinceEpoch;
    await db.customStatement('''INSERT INTO match_decisions(id,library_id,item_id,state,revision,origin,payload,updated_at) VALUES(?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET work_id=NULL,state=excluded.state,provider_id=NULL,remote_id=NULL,revision=excluded.revision,origin=excluded.origin,payload=excluded.payload,updated_at=excluded.updated_at''',
      [item.id,item.libraryId,item.id,'cleared',revision,'user','{"explicitClear":true}',now]);
    await reindex(item);
  });
  Future<void> override(Item item,String field,Object? value,{bool remove=false,bool locked=true,bool reset=false}) =>db.transaction(()async{
    if(!MediaRecordContract.fields('metadata')!.contains(field) || ['matchState','source','providerId','providerItemId'].contains(field)) throw const FormatException('This field is owned by matching');
    MediaRecordContract.validate(id:'metadata:${item.id}',kind:'metadata',libraryId:item.libraryId,itemId:item.id,data:{field:value});
    final id=stableId('${item.id}:$field');
    final revision=await _revision('catalog_overrides',id);
    await db.customStatement('''INSERT INTO catalog_overrides(id,library_id,item_id,field,value,removed,locked,revision,updated_at) VALUES(?,?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET value=excluded.value,removed=excluded.removed,locked=excluded.locked,revision=excluded.revision,updated_at=excluded.updated_at''',
      [id,item.libraryId,item.id,field,reset?null:jsonEncode(value),remove?1:0,reset?0:locked?1:0,revision,DateTime.now().millisecondsSinceEpoch]);
    await reindex(item);
  });
  Future<Map<String,dynamic>> resolve(Item item,Map<String,dynamic> local) async {
    final choice=await decision(item.id);
    final result=<String,dynamic>{...filenameHints(item.filename),...local};
    if(choice?['state']=='matched') {
      final row=await db.customSelect('SELECT payload FROM provider_snapshots WHERE work_id=?',variables:[Variable(choice!['work_id'] as String)]).getSingleOrNull();
      if(row != null) result.addAll(Map<String,dynamic>.from(jsonDecode(row.data['payload'] as String) as Map));
    }
    if(choice != null)result.addAll({'matchState':choice['state'],'source':choice['provider_id']??'filename'});
    final overrides=await db.customSelect('SELECT * FROM catalog_overrides WHERE item_id=?',variables:[Variable(item.id)]).get();
    for(final row in overrides) {
      if(row.data['removed']==1)result.remove(row.data['field']);
      else if(row.data['value'] != null)result[row.data['field'] as String]=jsonDecode(row.data['value'] as String);
    }
    return result;
  }
  Future<void> reindex(Item item) async {
    final legacy=await db.customSelect('SELECT payload FROM media_records WHERE id=? AND deleted=0',variables:[Variable('metadata:${item.id}')]).getSingleOrNull();
    final metadata=await resolve(item,legacy==null?{}:Map<String,dynamic>.from(jsonDecode(legacy.data['payload'] as String) as Map));
    final organization=await db.customSelect('SELECT payload FROM media_records WHERE id=? AND deleted=0',variables:[Variable('organization:${item.id}')]).getSingleOrNull();
    final tags=organization==null?'':((jsonDecode(organization.data['payload'] as String) as Map)['tags'] as List? ?? []).join(' ');
    await db.customStatement('DELETE FROM catalog_search WHERE item_id=?',[item.id]);
    await db.customStatement('INSERT INTO catalog_search(item_id,library_id,title,creator,tags) VALUES(?,?,?,?,?)',
      [item.id,item.libraryId,item.userTitle??metadata['title']??item.title,'${metadata['author']??''} ${metadata['artist']??''} ${metadata['credits']??''}',tags]);
  }
  Future<Map<String,List<Map<String,dynamic>>>> exportRows() async =>{
    for(final table in tables) table:(await db.customSelect('SELECT * FROM $table').get()).map((r)=>r.data).toList(),
  };
  Future<void> importRows(Object? input,{Set<String>? allowedLibraryIds}) async {
    if(input==null)return;
    if(input is! Map)throw const FormatException('Invalid typed catalog');
    for(final table in tables) {
      final rows=input[table];if(rows==null)continue;
      if(rows is! List || rows.length>100000)throw const FormatException('Invalid catalog rows');
      final columns=(await db.customSelect('PRAGMA table_info($table)').get()).map((r)=>r.data['name'] as String).toList();
      for(final value in rows) {
        if(value is! Map<String,dynamic> || value['id'] is! String || value['library_id'] is! String || value.keys.any((key)=>!columns.contains(key))) throw const FormatException('Invalid catalog identity');
        final libraryId=value['library_id'] as String;
        if(allowedLibraryIds != null&&!allowedLibraryIds.contains(libraryId))continue;
        if(await db.getLibraryById(libraryId)==null)continue;
        final itemId=value['item_id'];
        if(itemId != null && (await db.getItemById(itemId as String))?.libraryId != libraryId)throw const FormatException('Catalog asset ownership mismatch');
        MediaRecordContract.revision(value['updated_at']);
        if(value['revision'] != null)MediaRecordContract.revision(value['revision']);
        if(value['payload'] != null) {
          final raw=value['payload'];if(raw is! String || utf8.encode(raw).length>MediaRecordContract.maxPayloadBytes || jsonDecode(raw) is! Map)throw const FormatException('Invalid catalog payload');
        }
        final old=await db.customSelect('SELECT * FROM $table WHERE id=?',variables:[Variable(value['id'] as String)]).getSingleOrNull();
        if(old != null && (old.data['library_id']!=libraryId || old.data['item_id']!=itemId))throw const FormatException('Catalog ownership cannot change');
        for(final (key,target) in [('work_id','catalog_works'),('edition_id','catalog_editions'),('representation_id','playable_representations')]) {
          final id=value[key];if(id==null)continue;
          final parent=await db.customSelect('SELECT library_id FROM $target WHERE id=?',variables:[Variable(id as String)]).getSingleOrNull();
          if(parent?.data['library_id']!=libraryId)throw const FormatException('Catalog relationship is outside this library');
        }
        if(old != null) {
          final current=old.data['revision'] as int? ?? old.data['updated_at'] as int;
          final incoming=value['revision'] as int? ?? value['updated_at'] as int;
          if(incoming<=current)continue;
        }
        final keys=columns.where(value.containsKey).toList();
        await db.customStatement('INSERT INTO $table(${keys.join(',')}) VALUES(${keys.map((_)=>'?').join(',')}) ON CONFLICT(id) DO UPDATE SET ${keys.where((k)=>k!='id').map((k)=>'$k=excluded.$k').join(',')}',keys.map((key)=>value[key]).toList());
        if(itemId is String)await reindex((await db.getItemById(itemId))!);
      }
    }
  }

  static Map<String,dynamic> filenameHints(String filename) {
    final stem=filename.replaceFirst(RegExp(r'\.[^.]+$'),'').replaceAll(RegExp(r'[._]'),' ');
    final edition=RegExp(r"\b(extended(?: edition)?|director'?s? cut|theatrical|unrated|final cut|remastered)\b",caseSensitive:false).firstMatch(stem)?.group(0);
    final representation=RegExp(r'\b(2160p|1080p|720p|4k|hdr10\+?|dolby vision|hevc|h264|h265|x264|x265)\b',caseSensitive:false).allMatches(stem).map((m)=>m.group(0)).join(' ');
    final year=RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(stem);
    final episode=RegExp(r'\b[Ss](\d{1,2})[Ee](\d{1,3})\b|\b(\d{1,2})x(\d{1,3})\b').firstMatch(stem);
    final date=RegExp(r'\b(20\d{2})[- ](\d{2})[- ](\d{2})\b').firstMatch(stem);
    final explicit=RegExp(r'\{(tmdb|imdb|tvdb)[-:]([a-zA-Z0-9]+)\}').firstMatch(stem);
    final markers=[if(year!=null)year.start,if(episode!=null)episode.start,if(date!=null)date.start,if(explicit!=null)explicit.start];
    markers.sort();
    var title=markers.isEmpty?stem:stem.substring(0,markers.first);
    title=title.replaceAll(RegExp(r"\b(extended(?: edition)?|director'?s? cut|theatrical|unrated|final cut|remastered|2160p|1080p|720p|4k|hdr10\+?|hevc|x264|x265)\b",caseSensitive:false),'').replaceAll(RegExp(r'[\s(\[\-]+$'),'').trim();
    return {'title':title,'year':year==null?null:int.parse(year[0]!),
      'season':episode==null?null:int.parse(episode[1]??episode[3]!),
      'episode':episode==null?null:int.parse(episode[2]??episode[4]!),
      'edition':edition,'representation':representation,
      'airDate':date==null?null:'${date[1]}-${date[2]}-${date[3]}',
      'explicitProvider':explicit?[1],'explicitId':explicit?[2],
      'part':RegExp(r'\b(?:cd|disc|part)[ -]?(\d+)\b',caseSensitive:false).firstMatch(stem)?.group(1),
      'extra':RegExp(r'\b(trailer|featurette|behind the scenes|deleted scenes)\b',caseSensitive:false).hasMatch(stem),
      'matchState':'unmatched','source':'filename'};
  }
}
