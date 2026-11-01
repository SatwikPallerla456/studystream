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
import '../../domain/reader/reader_session_store.dart';
import '../reader/reader_preferences_sheet.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/study_ui.dart';
import '../../shared/widgets/media_categories.dart';
import '../../shared/widgets/tangerine_controls.dart';
import '../../core/theme/app_theme.dart';

class LibrarySourcesScreen extends ConsumerStatefulWidget {
  const LibrarySourcesScreen({super.key, required this.libraryId});
  final String libraryId;
  @override
  ConsumerState<LibrarySourcesScreen> createState() => _LibrarySourcesState();
}

class _LibrarySourcesState extends ConsumerState<LibrarySourcesScreen> {
  List<LibrarySource> _sources = [];
  Map<String, Map<String, dynamic>> _scans = {};
  LibraryKind _kind = LibraryKind.mixed;
  ScanCancellationToken? _token;
  ScanProgress? _progress;
  String? _message;
  bool _loading = true;
  bool _savingKind = false;
  late final AppDatabase _db;
  late final MediaCatalogRepository _catalog;
  @override
  void initState() {
    super.initState();
    _db = ref.read(appDatabaseProvider);
    _catalog = MediaCatalogRepository(_db);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final sources = await _catalog.sources(widget.libraryId);
      final scans = <String, Map<String, dynamic>>{};
      for (final source in sources) {
        final row = await _db
            .customSelect(
              'SELECT * FROM source_scan_sessions WHERE source_id=? ORDER BY generation DESC LIMIT 1',
              variables: [drift.Variable(source.id)],
            )
            .getSingleOrNull();
        if (row != null) scans[source.id] = row.data;
      }
      final kind = await _catalog.libraryKind(widget.libraryId);
      if (mounted)
        setState(() {
          _sources = sources;
          _scans = scans;
          _kind = kind;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _message =
              'Library settings could not load. Reopen this screen and try again.';
        });
    }
  }

  Future<void> _scan(LibrarySource source) async {
    if (_token != null) return;
    final token = ScanCancellationToken();
    setState(() {
      _token = token;
      _message = null;
    });
    try {
      final library = await _db.getLibraryById(widget.libraryId);
      final result = await ref
          .read(libraryIndexerProvider)
          .scanRootFolder(
            rootFolderPath: source.root,
            title: library!.title,
            existingLibraryId: source.libraryId,
            source: source,
            cancellationToken: token,
            onProgress: (value) {
              if (mounted) setState(() => _progress = value);
            },
          );
      if (mounted)
        setState(
          () => _message =
              '${result.importedItems} files indexed · ${result.missingItems} unavailable${result.errors.isEmpty ? '' : ' · ${result.errors.length} need attention'}',
        );
    } on ScanCancelledException {
      if (mounted)
        setState(
          () => _message =
              'Cancelled. Existing media, notes and progress were kept.',
        );
    } on Object catch (error) {
      if (mounted)
        setState(
          () => _message =
              'The folder could not be scanned. Check its availability and file access, then retry.',
        );
    } finally {
      if (mounted) {
        setState(() {
          _token = null;
          _progress = null;
        });
        await _load();
      }
    }
  }

  Future<void> _choose({LibrarySource? source}) async {
    final root = await FilePicker.platform.getDirectoryPath(
      dialogTitle: source == null
          ? 'Add a library source'
          : 'Relink this source',
    );
    if (root == null || !mounted) return;
    try {
      await FolderAccess.retain(root);
      final selected = source == null
          ? await _catalog.addSource(widget.libraryId, root)
          : source;
      if (source != null) await _catalog.relinkSource(source, root);
      await _load();
      await _scan(_sources.firstWhere((s) => s.id == selected.id));
    } on Object catch (error) {
      if (mounted)
        setState(
          () => _message =
              'This folder could not be added or relinked. Check file access and try again.',
        );
    }
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: 'Library settings', showBack: true),
    body: StudyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Library content',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TangerineChoicePicker<LibraryKind>(
            value: _kind,
            label: 'Content',
            icon: mediaCategoryIcon(_kind),
            choices: [
              for (final kind in LibraryKind.values)
                TangerineChoice(
                  value: kind,
                  label: kind.label,
                  icon: mediaCategoryIcon(kind),
                ),
            ],
            onChanged: _token != null || _loading || _savingKind
                ? null
                : (value) async {
                    if (_savingKind) return;
                    setState(() => _savingKind = true);
                    try {
                      await _catalog.setLibraryKind(widget.libraryId, value);
                      if (mounted) setState(() => _kind = value);
                    } catch (_) {
                      if (mounted)
                        setState(
                          () => _message =
                              'The library category could not be saved. Reopen settings and try again.',
                        );
                    } finally {
                      if (mounted) setState(() => _savingKind = false);
                    }
                  },
          ),
          const SizedBox(height: 16),
          if ({
            LibraryKind.books,
            LibraryKind.comics,
            LibraryKind.documents,
            LibraryKind.courses,
            LibraryKind.mixed,
          }.contains(_kind))
            OutlinedButton.icon(
              onPressed: () => showReaderPreferences(
                context: context,
                database: _db,
                libraryId: widget.libraryId,
                initialScope: ReaderPreferenceScope.library,
              ),
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('Library reading defaults'),
            ),
          const SizedBox(height: 24),
          StudySectionHeader(
            title: 'Connected folders',
            description:
                'Scan each source independently, or relink a folder that has moved.',
            trailing: TangerineInteraction(
              enabled: _token == null && !_loading,
              child: FilledButton.icon(
                onPressed: _token != null || _loading ? null : () => _choose(),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Add source folder'),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          if (_loading) const LinearProgressIndicator(),
          if (_token != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress?.fraction),
            Text(_progress?.phase ?? 'Preparing scan'),
            TextButton(
              onPressed: _token!.cancel,
              child: const Text('Cancel scan'),
            ),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Semantics(
                liveRegion: true,
                child: SelectableText(_message!),
              ),
            ),
          for (final source in _sources)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          source.unavailable
                              ? Icons.cloud_off_outlined
                              : Icons.folder_open_rounded,
                          color: source.unavailable
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source.namespace.isEmpty
                                  ? 'Original source'
                                  : source.root.split(RegExp(r'[/\\]')).last,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              source.root,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  StudyStatusBadge(
                    label:
                        '${source.unavailable ? 'Unavailable' : 'Available'} · ${_scans[source.id]?['outcome'] ?? 'Not scanned'}',
                    icon: source.unavailable
                        ? Icons.cloud_off_outlined
                        : Icons.check_circle_outline_rounded,
                    tone: source.unavailable
                        ? StudyStatusTone.warning
                        : StudyStatusTone.neutral,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TangerineInteraction(
                        enabled: _token == null,
                        child: TextButton.icon(
                          onPressed: _token != null
                              ? null
                              : () => _scan(source),
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Scan / retry'),
                        ),
                      ),
                      TangerineInteraction(
                        enabled: _token == null,
                        child: TextButton.icon(
                          onPressed: _token != null
                              ? null
                              : () => _choose(source: source),
                          icon: const Icon(Icons.folder_copy_outlined),
                          label: const Text('Relink folder'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
