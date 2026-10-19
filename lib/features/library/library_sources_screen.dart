import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/indexer/library_indexer.dart';
import '../../data/platform/folder_access.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/study_ui.dart';

class LibrarySourcesScreen extends ConsumerStatefulWidget {
  const LibrarySourcesScreen({super.key,required this.libraryId});
  final String libraryId;
  @override ConsumerState<LibrarySourcesScreen> createState()=>_LibrarySourcesState();
}
class _LibrarySourcesState extends ConsumerState<LibrarySourcesScreen> {
  List<LibrarySource> _sources=[];
  Map<String,Map<String,dynamic>> _scans={};
  LibraryKind _kind=LibraryKind.mixed;
  ScanCancellationToken? _token;
  ScanProgress? _progress;
  String? _message;
  bool _loading=true;
  late final AppDatabase _db;
  late final MediaCatalogRepository _catalog;
  @override void initState(){super.initState();_db=ref.read(appDatabaseProvider);_catalog=MediaCatalogRepository(_db);unawaited(_load());}
  Future<void> _load() async {
    final sources=await _catalog.sources(widget.libraryId);
    final scans=<String,Map<String,dynamic>>{};
    for(final source in sources) {
      final row=await _db.customSelect('SELECT * FROM source_scan_sessions WHERE source_id=? ORDER BY generation DESC LIMIT 1',variables:[drift.Variable(source.id)]).getSingleOrNull();
      if(row != null) scans[source.id]=row.data;
    }
    final kind=await _catalog.libraryKind(widget.libraryId);
    if(mounted)setState((){_sources=sources;_scans=scans;_kind=kind;_loading=false;});
  }
  Future<void> _scan(LibrarySource source) async {
    if(_token != null)return;
    final token=ScanCancellationToken();setState((){_token=token;_message=null;});
    try {
      final library=await _db.getLibraryById(widget.libraryId);
      final result=await ref.read(libraryIndexerProvider).scanRootFolder(rootFolderPath:source.root,title:library!.title,
        existingLibraryId:source.libraryId,source:source,cancellationToken:token,onProgress:(value){if(mounted)setState(()=>_progress=value);});
      if(mounted)setState(()=>_message='${result.outcome}: ${result.importedItems} indexed, ${result.missingItems} missing. ${result.errors.join('\n')}');
    } on ScanCancelledException {if(mounted)setState(()=>_message='Cancelled. Existing media and Study history were kept.');}
    on Object catch(error){if(mounted)setState(()=>_message=error.toString());}
    finally {if(mounted){setState((){_token=null;_progress=null;});await _load();}}
  }
  Future<void> _choose({LibrarySource? source}) async {
    final root=await FilePicker.platform.getDirectoryPath(dialogTitle:source==null?'Add a library source':'Relink this source');
    if(root==null||!mounted)return;
    try {
      await FolderAccess.retain(root);
      final selected=source==null?await _catalog.addSource(widget.libraryId,root):source;
      if(source != null)await _catalog.relinkSource(source,root);
      await _load();
      await _scan(_sources.firstWhere((s)=>s.id==selected.id));
    } on Object catch(error){if(mounted)setState(()=>_message=error.toString());}
  }
  @override void dispose(){_token?.cancel();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:const AppTopBar(title:'Library sources',showBack:true),body:StudyPage(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    DropdownButtonFormField<LibraryKind>(initialValue:_kind,decoration:const InputDecoration(labelText:'Library content'),items:LibraryKind.values.map((kind)=>DropdownMenuItem(value:kind,child:Text(kind.label))).toList(),onChanged:_token != null?null:(value)async{if(value==null)return;await _catalog.setLibraryKind(widget.libraryId,value);if(mounted)setState(()=>_kind=value);}),
    const SizedBox(height:24),
    FilledButton.icon(onPressed:_token != null?null:()=>_choose(),icon:const Icon(Icons.create_new_folder_outlined),label:const Text('Add source folder')),
    if(_loading)const LinearProgressIndicator(),
    if(_token != null)...[const SizedBox(height:16),LinearProgressIndicator(value:_progress?.fraction),Text(_progress?.phase??'Preparing scan'),TextButton(onPressed:_token!.cancel,child:const Text('Cancel scan'))],
    if(_message != null)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:SelectableText(_message!)),
    for(final source in _sources)Card(child:ListTile(isThreeLine:true,leading:Icon(source.unavailable?Icons.cloud_off:Icons.folder_outlined),
      title:Text(source.namespace.isEmpty?'Original source':source.root.split(RegExp(r'[/\\]')).last),
      subtitle:Text('${source.root}\n${source.unavailable?'Unavailable':'Available'} · ${_scans[source.id]?['outcome']??'Not scanned'}'),
      trailing:PopupMenuButton<String>(enabled:_token==null,onSelected:(value)=>value=='scan'?_scan(source):_choose(source:source),itemBuilder:(_)=>const [PopupMenuItem(value:'scan',child:Text('Scan / retry')),PopupMenuItem(value:'relink',child:Text('Relink folder'))]))),
  ])));
}
