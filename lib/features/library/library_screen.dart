import 'library_processing_screen.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../core/constants/supported_extensions.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/indexer/library_indexer.dart';
import '../../data/platform/folder_access.dart';
import '../../shared/widgets/item_artwork.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/study_animated_list.dart';
import '../../shared/widgets/study_ui.dart';
import '../../shared/widgets/study_motion.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import 'typed_library_screen.dart';
import 'collections_screen.dart';

enum _LessonFilter { all, inProgress, completed, missing }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, required this.libraryId});

  final String libraryId;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  String? _selectedSectionId;
  Library? _library;
  LibraryKind _kind = LibraryKind.mixed;
  Future<Item?>? _resumeItem;
  bool _loading = true;
  bool _rescanning = false;
  _LessonFilter _filter = _LessonFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final database = ref.read(appDatabaseProvider);
    final library = await database.getLibraryById(widget.libraryId);
    final kind = library == null
        ? LibraryKind.mixed
        : await MediaCatalogRepository(database).libraryKind(library.id);
    if (!mounted) return;
    setState(() {
      _kind = kind;
      _library = library;
      _resumeItem = library == null
          ? null
          : _findResumeItem(database, library.id);
      _loading = false;
    });
  }

  Future<Item?> _findResumeItem(AppDatabase database, String libraryId) async {
    final row = await database
        .customSelect(
          """SELECT i.* FROM items i
      LEFT JOIN playback_progress p ON p.item_id=i.id
      LEFT JOIN reading_progress r ON r.item_id=i.id
      WHERE i.library_id=? AND i.unavailable=0
      ORDER BY CASE WHEN COALESCE(p.completed,0)=0 AND COALESCE(r.completed,0)=0
        THEN 0 ELSE 1 END,
      CASE WHEN COALESCE(p.completed,0)=0 AND COALESCE(r.completed,0)=0
        THEN COALESCE(p.last_opened_at,r.last_opened_at,-1) ELSE -1 END DESC,
      i.order_index,i.id LIMIT 1""",
          variables: [drift.Variable(libraryId)],
          readsFrom: {
            database.items,
            database.playbackProgress,
            database.readingProgress,
          },
        )
        .getSingleOrNull();
    return row == null ? null : database.items.map(row.data);
  }

  Future<void> _rescan() async {
    final library = _library;
    if (library == null || _rescanning) return;
    if (library.rootFolderPath.startsWith('remote:')) {
      await ref.read(lanSyncClientProvider).sync();
      if (mounted) _message('Remote library refreshed');
      return;
    }
    if (library.rootFolderPath.startsWith('import:')) {
      _message(
        'This collection contains individually imported files. Relink missing files individually; folder refresh requires linked source folders.',
      );
      return;
    }
    var root = library.rootFolderPath;
    if (!await Directory(root).exists()) {
      final selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Locate the moved library folder',
      );
      if (selected == null || !mounted) return;
      await FolderAccess.retain(selected);
      root = selected;
    }
    if (!mounted) return;
    setState(() => _rescanning = true);
    try {
      final result = await ref
          .read(libraryIndexerProvider)
          .scanRootFolder(
            rootFolderPath: root,
            title: library.title,
            existingLibraryId: library.id,
          );
      if (!mounted) return;
      _message(
        result.missingItems == 0
            ? '${result.importedItems} lessons refreshed'
            : '${result.importedItems} lessons refreshed · ${result.missingItems} need relinking',
      );
      await _load();
    } catch (_) {
      if (mounted) {
        _message('The library could not be rescanned. Check folder access.');
      }
    } finally {
      if (mounted) setState(() => _rescanning = false);
    }
  }

  Future<void> _editLibrary() async {
    final library = _library;
    if (library == null) return;
    final titleController = TextEditingController(text: library.title);
    final descriptionController = TextEditingController(
      text: library.description,
    );
    var coverPath = library.coverPath;
    var validTitle = titleController.text.trim().isNotEmpty;
    final result =
        await showStudyAdaptiveModal<
          ({String title, String description, String? coverPath})
        >(
          context: context,
          disposeOnClose: [titleController, descriptionController],
          builder: (modalContext) => StatefulBuilder(
            builder: (context, setModalState) => StudyModalFrame(
              title: 'Edit library',
              description:
                  'Update the way this collection appears in Tangerine.',
              icon: Icons.edit_outlined,
              primaryAction: FilledButton(
                onPressed: validTitle
                    ? () => Navigator.pop(modalContext, (
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        coverPath: coverPath,
                      ))
                    : null,
                child: const Text('Save changes'),
              ),
              secondaryAction: TextButton(
                onPressed: () => Navigator.pop(modalContext),
                child: const Text('Cancel'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Library title',
                      errorText: validTitle ? null : 'Enter a library title',
                    ),
                    onChanged: (value) => setModalState(
                      () => validTitle = value.trim().isNotEmpty,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Cover artwork',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      StudyArtwork(path: coverPath, kind: 'library', size: 72),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Wrap(
                          spacing: AppSpace.xs,
                          runSpacing: AppSpace.xs,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await FilePicker.platform
                                    .pickFiles(
                                      dialogTitle: 'Choose a library cover',
                                      type: FileType.image,
                                      allowMultiple: false,
                                    );
                                final path = picked?.files.single.path;
                                if (path != null) {
                                  setModalState(() => coverPath = path);
                                }
                              },
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                coverPath == null
                                    ? 'Choose image'
                                    : 'Change image',
                              ),
                            ),
                            if (coverPath != null)
                              TextButton.icon(
                                onPressed: () =>
                                    setModalState(() => coverPath = null),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Remove'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

    if (result == null) return;
    await ref
        .read(appDatabaseProvider)
        .updateLibraryMetadata(
          id: library.id,
          title: result.title,
          description: result.description,
          coverPath: result.coverPath,
        );
    await _load();
    if (mounted) _message('Library details updated');
  }

  Future<void> _setCompletion(Item item, bool completed) async {
    await ref
        .read(appDatabaseProvider)
        .setItemCompletion(item: item, completed: completed);
    if (mounted) {
      _message(
        completed ? 'Lesson marked complete' : 'Lesson marked incomplete',
      );
    }
  }

  Future<void> _editItemTitle(Item item) async {
    final controller = TextEditingController(
      text: item.userTitle ?? item.title,
    );
    final result = await showStudyAdaptiveModal<String>(
      context: context,
      disposeOnClose: [controller],
      builder: (modalContext) => StudyModalFrame(
        title: 'Edit lesson title',
        description:
            'This changes only the display title. The source filename stays the same.',
        icon: Icons.drive_file_rename_outline_rounded,
        primaryAction: FilledButton(
          onPressed: () => Navigator.pop(modalContext, controller.text.trim()),
          child: const Text('Save title'),
        ),
        secondaryAction: TextButton(
          onPressed: () => Navigator.pop(modalContext),
          child: const Text('Cancel'),
        ),
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Display title',
            helperText: 'Leave blank to use the title from the filename.',
          ),
          onSubmitted: (value) => Navigator.pop(modalContext, value.trim()),
        ),
      ),
    );

    if (result == null) return;
    await ref.read(appDatabaseProvider).updateItemTitle(item.id, result);
    if (mounted) _message('Lesson title updated');
  }

  Future<void> _relink(Item item) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Relink ${item.filename}',
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    if (!isSupportedImportFile(path) ||
        inferItemType(path).name != item.itemType) {
      if (mounted) _message('Choose a supported file of the same lesson type.');
      return;
    }
    final file = File(path);
    try {
      final library = _library;
      if (library == null) return;
      final importedFiles = library.rootFolderPath.startsWith('import:');
      final canonicalRoot = importedFiles
          ? null
          : await Directory(library.rootFolderPath).resolveSymbolicLinks();
      final canonicalFile = await file.resolveSymbolicLinks();
      if (canonicalRoot != null &&
          canonicalFile != canonicalRoot &&
          !canonicalFile.startsWith(
            '$canonicalRoot${Platform.pathSeparator}',
          )) {
        _message('Choose a file inside this library folder.');
        return;
      }
      if (importedFiles) await FolderAccess.retain(path);
      final stat = await file.stat();
      final fingerprint = await fingerprintFile(file);
      await ref
          .read(appDatabaseProvider)
          .relinkItem(
            itemId: item.id,
            filePath: path,
            filename: p.basename(path),
            relativePath: importedFiles
                ? canonicalFile
                : p.relative(path, from: library.rootFolderPath),
            modifiedAt: stat.modified.millisecondsSinceEpoch,
            fileSize: stat.size,
            fingerprint: fingerprint,
          );
      if (mounted) _message('Lesson relinked. Progress was preserved.');
    } catch (_) {
      if (mounted) {
        _message(
          'This file could not be relinked. Check access and try again.',
        );
      }
    }
  }

  void _open(Item item) {
    if (item.unavailable) {
      _relink(item);
      return;
    }
    final route = switch (item.itemType) {
      'video' || 'audio' => '/player/${item.id}',
      'pdf' => '/pdf/${item.id}',
      _ => '/resource/${item.id}',
    };
    context.push(route);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    final library = _library;
    if (_loading) {
      return const Scaffold(
        body: StudyPage(child: ContentLoadingState(label: 'Loading library')),
      );
    }
    if (library == null) {
      return Scaffold(
        appBar: AppTopBar(
          title: 'Library',
          showBack: true,
          showHome: true,
          onBack: () => context.go('/'),
        ),
        body: StudyPage(
          child: ContentState(
            icon: Icons.folder_off_rounded,
            title: 'Library not found',
            message:
                'It may have been removed from this device. Your source folder was not changed.',
            action: FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to home'),
            ),
            tone: ContentStateTone.warning,
          ),
        ),
      );
    }

    if (_kind != LibraryKind.courses)
      return TypedLibraryScreen(
        library: library,
        kind: _kind,
        onChanged: _load,
      );
    return Scaffold(
      appBar: AppTopBar(
        title: cleanDisplayTitle(library.title),
        showBack: true,
        showHome: true,
        onBack: () => context.go('/'),
        actions: [
          LibraryProcessingButton(libraryId: library.id),
          IconButton(
            tooltip: 'Collections and albums',
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CollectionsScreen(libraryId: library.id),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Library type and sources',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () async {
              await context.push('/library/${library.id}/sources');
              if (mounted) await _load();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<SectionProgressEntry>>(
        stream: database.watchSectionProgressForLibrary(widget.libraryId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const StudyPage(
              child: ContentState(
                icon: Icons.error_outline_rounded,
                title: 'This library could not load',
                message:
                    'The local index is temporarily unavailable. Your source files are safe.',
                tone: ContentStateTone.error,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const StudyPage(
              child: ContentLoadingState(label: 'Loading library sections'),
            );
          }
          final sections = snapshot.data ?? const [];
          if (sections.isEmpty) {
            return StudyPage(
              child: Column(
                children: [
                  _LibraryHero(
                    library: library,
                    stats: database.getLibraryStats(library.id),
                    resumeItem: _resumeItem,
                    rescanning: _rescanning,
                    onResume: _open,
                    onEdit: _editLibrary,
                    onRescan: _rescan,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  ContentState(
                    icon: Icons.video_collection_outlined,
                    title: 'No supported lessons found',
                    message:
                        'Add media, PDF, text, image, or common document files to the folder, then rescan.',
                    action: FilledButton.icon(
                      onPressed: _rescanning ? null : _rescan,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Rescan library'),
                    ),
                  ),
                ],
              ),
            );
          }
          final selected = sections.firstWhere(
            (entry) => entry.section.id == _selectedSectionId,
            orElse: () => sections.first,
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AppBreakpoints.medium;
              if (wide) {
                return _DesktopLibraryLayout(
                  library: library,
                  database: database,
                  sections: sections,
                  selected: selected,
                  resumeItem: _resumeItem,
                  rescanning: _rescanning,
                  searchController: _searchController,
                  filter: _filter,
                  onSelectSection: (id) =>
                      setState(() => _selectedSectionId = id),
                  onSearch: (_) => setState(() {}),
                  onFilter: (value) => setState(() => _filter = value),
                  onResume: _open,
                  onEditLibrary: _editLibrary,
                  onRescan: _rescan,
                  onOpen: _open,
                  onCompletion: _setCompletion,
                  onEditTitle: _editItemTitle,
                );
              }
              return _CompactLibraryLayout(
                library: library,
                database: database,
                sections: sections,
                selected: selected,
                resumeItem: _resumeItem,
                rescanning: _rescanning,
                searchController: _searchController,
                filter: _filter,
                onSelectSection: (id) =>
                    setState(() => _selectedSectionId = id),
                onSearch: (_) => setState(() {}),
                onFilter: (value) => setState(() => _filter = value),
                onResume: _open,
                onEditLibrary: _editLibrary,
                onRescan: _rescan,
                onOpen: _open,
                onCompletion: _setCompletion,
                onEditTitle: _editItemTitle,
              );
            },
          );
        },
      ),
    );
  }
}

class _DesktopLibraryLayout extends StatelessWidget {
  const _DesktopLibraryLayout({
    required this.library,
    required this.database,
    required this.sections,
    required this.selected,
    required this.resumeItem,
    required this.rescanning,
    required this.searchController,
    required this.filter,
    required this.onSelectSection,
    required this.onSearch,
    required this.onFilter,
    required this.onResume,
    required this.onEditLibrary,
    required this.onRescan,
    required this.onOpen,
    required this.onCompletion,
    required this.onEditTitle,
  });

  final Library library;
  final AppDatabase database;
  final List<SectionProgressEntry> sections;
  final SectionProgressEntry selected;
  final Future<Item?>? resumeItem;
  final bool rescanning;
  final TextEditingController searchController;
  final _LessonFilter filter;
  final ValueChanged<String> onSelectSection;
  final ValueChanged<String> onSearch;
  final ValueChanged<_LessonFilter> onFilter;
  final ValueChanged<Item> onResume;
  final VoidCallback onEditLibrary;
  final VoidCallback onRescan;
  final ValueChanged<Item> onOpen;
  final void Function(Item item, bool completed) onCompletion;
  final ValueChanged<Item> onEditTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.lg,
            AppSpace.md,
          ),
          child: _LibraryHero(
            library: library,
            stats: database.getLibraryStats(library.id),
            resumeItem: resumeItem,
            rescanning: rescanning,
            onResume: onResume,
            onEdit: onEditLibrary,
            onRescan: onRescan,
          ),
        ),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 304,
                child: _SectionNavigation(
                  sections: sections,
                  selectedId: selected.section.id,
                  onSelect: onSelectSection,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg,
                    AppSpace.md,
                    AppSpace.lg,
                    AppSpace.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LessonToolbar(
                        sectionTitle: selected.section.title,
                        controller: searchController,
                        filter: filter,
                        onSearch: onSearch,
                        onFilter: onFilter,
                      ),
                      const SizedBox(height: AppSpace.md),
                      Expanded(
                        child: _LessonList(
                          database: database,
                          section: selected.section,
                          query: searchController.text,
                          filter: filter,
                          onOpen: onOpen,
                          onCompletion: onCompletion,
                          onEditTitle: onEditTitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactLibraryLayout extends StatelessWidget {
  const _CompactLibraryLayout({
    required this.library,
    required this.database,
    required this.sections,
    required this.selected,
    required this.resumeItem,
    required this.rescanning,
    required this.searchController,
    required this.filter,
    required this.onSelectSection,
    required this.onSearch,
    required this.onFilter,
    required this.onResume,
    required this.onEditLibrary,
    required this.onRescan,
    required this.onOpen,
    required this.onCompletion,
    required this.onEditTitle,
  });

  final Library library;
  final AppDatabase database;
  final List<SectionProgressEntry> sections;
  final SectionProgressEntry selected;
  final Future<Item?>? resumeItem;
  final bool rescanning;
  final TextEditingController searchController;
  final _LessonFilter filter;
  final ValueChanged<String> onSelectSection;
  final ValueChanged<String> onSearch;
  final ValueChanged<_LessonFilter> onFilter;
  final ValueChanged<Item> onResume;
  final VoidCallback onEditLibrary;
  final VoidCallback onRescan;
  final ValueChanged<Item> onOpen;
  final void Function(Item item, bool completed) onCompletion;
  final ValueChanged<Item> onEditTitle;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _LibraryHero(
              library: library,
              stats: database.getLibraryStats(library.id),
              resumeItem: resumeItem,
              rescanning: rescanning,
              onResume: onResume,
              onEdit: onEditLibrary,
              onRescan: onRescan,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: DropdownButtonFormField<String>(
              initialValue: selected.section.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Section',
                prefixIcon: Icon(Icons.segment_rounded),
              ),
              items: [
                for (final entry in sections)
                  DropdownMenuItem(
                    value: entry.section.id,
                    child: Text(
                      '${cleanDisplayTitle(entry.section.title)} · ${entry.completedItems}/${entry.totalItems}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onSelectSection(value);
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
          ),
          sliver: SliverToBoxAdapter(
            child: _LessonToolbar(
              sectionTitle: selected.section.title,
              controller: searchController,
              filter: filter,
              onSearch: onSearch,
              onFilter: onFilter,
              compact: true,
            ),
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          0,
          AppSpace.md,
          AppSpace.md,
        ),
        child: _LessonList(
          database: database,
          section: selected.section,
          query: searchController.text,
          filter: filter,
          onOpen: onOpen,
          onCompletion: onCompletion,
          onEditTitle: onEditTitle,
        ),
      ),
    );
  }
}

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({
    required this.library,
    required this.stats,
    required this.resumeItem,
    required this.rescanning,
    required this.onResume,
    required this.onEdit,
    required this.onRescan,
  });

  final Library library;
  final Future<LibraryStats> stats;
  final Future<Item?>? resumeItem;
  final bool rescanning;
  final ValueChanged<Item> onResume;
  final VoidCallback onEdit;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return StudySurface(
      emphasized: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final artwork = LibraryArtwork(
            library: library,
            size: compact ? 92 : 136,
            radius: AppRadius.lg,
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: [
                  const StudyStatusBadge(
                    label: 'Learning library',
                    icon: Icons.folder_copy_outlined,
                    tone: StudyStatusTone.primary,
                  ),
                  if (library.unavailable)
                    const StudyStatusBadge(
                      label: 'Folder unavailable',
                      icon: Icons.folder_off_rounded,
                      tone: StudyStatusTone.error,
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                cleanDisplayTitle(library.title),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (library.description.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  library.description.trim(),
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: AppSpace.md),
              FutureBuilder<LibraryStats>(
                future: stats,
                builder: (context, snapshot) {
                  final value = snapshot.data;
                  if (value == null) {
                    return const StudySkeleton(height: 38);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StudyProgress(
                        value: value.percent / 100,
                        label:
                            '${value.completedItems} of ${value.totalItems} lessons complete',
                        showPercentage: true,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      StudyMeta(
                        items: [
                          '${value.inProgressItems} in progress',
                          if (library.lastScannedAt != null)
                            'Scanned ${_relativeTime(library.lastScannedAt!)}',
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpace.md),
              Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: [
                  FutureBuilder<Item?>(
                    future: resumeItem,
                    builder: (context, snapshot) => FilledButton.icon(
                      onPressed: snapshot.data == null
                          ? null
                          : () => onResume(snapshot.data!),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Resume learning'),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit details'),
                  ),
                  IconButton(
                    tooltip: 'Rescan library',
                    onPressed: rescanning ? null : onRescan,
                    icon: rescanning
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                artwork,
                const SizedBox(height: AppSpace.md),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              artwork,
              const SizedBox(width: AppSpace.lg),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }

  static String _relativeTime(int milliseconds) {
    final difference = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(milliseconds),
    );
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    return '${difference.inDays} d ago';
  }
}

class _SectionNavigation extends StatefulWidget {
  const _SectionNavigation({
    required this.sections,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SectionProgressEntry> sections;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<_SectionNavigation> createState() => _SectionNavigationState();
}

class _SectionNavigationState extends State<_SectionNavigation> {
  final _collapsed = <String>{};

  List<_SectionNode> _tree() {
    final ids = widget.sections.map((entry) => entry.section.id).toSet();
    final children = <String?, List<SectionProgressEntry>>{};
    for (final entry in widget.sections) {
      final parent = entry.section.parentSectionId;
      final validParent = parent != entry.section.id && ids.contains(parent);
      children.putIfAbsent(validParent ? parent : null, () => []).add(entry);
    }
    final visited = <String>{};
    _SectionNode node(SectionProgressEntry entry) {
      visited.add(entry.section.id);
      return _SectionNode(entry, [
        for (final child in children[entry.section.id] ?? const [])
          if (!visited.contains(child.section.id)) node(child),
      ]);
    }

    final roots = [for (final entry in children[null] ?? const []) node(entry)];
    // Keep imported legacy/orphaned sections reachable, including malformed
    // cyclic parent links, without recursing into a folder twice.
    for (final entry in widget.sections) {
      if (!visited.contains(entry.section.id)) roots.add(node(entry));
    }
    return roots;
  }

  @override
  Widget build(BuildContext context) {
    final roots = _tree();
    final visible = <({_SectionNode node, int depth})>[];
    void append(_SectionNode node, int depth) {
      visible.add((node: node, depth: depth));
      if (!_collapsed.contains(node.entry.section.id)) {
        for (final child in node.children) {
          append(child, depth + 1);
        }
      }
    }

    for (final root in roots) {
      append(root, 0);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.md,
        AppSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sections', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.xxs),
          Text(
            '${widget.sections.length} ${widget.sections.length == 1 ? 'section' : 'sections'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.md),
          Expanded(
            child: StudyAnimatedList<({_SectionNode node, int depth})>(
              items: visible,
              itemId: (row) => row.node.entry.section.id,
              emptyState: const SizedBox.shrink(),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.xs),
              itemBuilder: (context, row) =>
                  _branch(context, row.node, row.depth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branch(BuildContext context, _SectionNode node, int depth) {
    final entry = node.entry;
    final id = entry.section.id;
    final title = cleanDisplayTitle(entry.section.title);
    final expanded = !_collapsed.contains(id);
    return Padding(
      padding: EdgeInsets.only(left: depth.clamp(0, 3) * AppSpace.sm),
      child: StudySurface(
        key: ValueKey('section-$id'),
        selected: id == widget.selectedId,
        padding: const EdgeInsets.all(AppSpace.sm),
        onTap: () => widget.onSelect(id),
        semanticLabel:
            '$title, ${entry.completedItems} of ${entry.totalItems} lessons complete',
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    '${entry.completedItems}/${entry.totalItems}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  StudyProgress(value: entry.progressPercent / 100, height: 5),
                ],
              ),
            ),
            if (node.children.isNotEmpty)
              Semantics(
                expanded: expanded,
                child: IconButton(
                  tooltip: '${expanded ? 'Collapse' : 'Expand'} $title',
                  onPressed: () => setState(() {
                    if (expanded) {
                      _collapsed.add(id);
                    } else {
                      _collapsed.remove(id);
                    }
                  }),
                  icon: Icon(
                    expanded
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionNode {
  const _SectionNode(this.entry, this.children);

  final SectionProgressEntry entry;
  final List<_SectionNode> children;
}

class _LessonToolbar extends StatelessWidget {
  const _LessonToolbar({
    required this.sectionTitle,
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
    this.compact = false,
  });

  final String sectionTitle;
  final TextEditingController controller;
  final _LessonFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_LessonFilter> onFilter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All', _LessonFilter.all),
          const SizedBox(width: AppSpace.xs),
          _filterChip('In progress', _LessonFilter.inProgress),
          const SizedBox(width: AppSpace.xs),
          _filterChip('Complete', _LessonFilter.completed),
          const SizedBox(width: AppSpace.xs),
          _filterChip('Missing', _LessonFilter.missing),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudySectionHeader(
          title: cleanDisplayTitle(sectionTitle),
          description: 'Choose a lesson or filter this section.',
          compact: compact,
        ),
        const SizedBox(height: AppSpace.md),
        if (compact) ...[
          StudySearchField(
            controller: controller,
            hintText: 'Search this section',
            onChanged: onSearch,
          ),
          const SizedBox(height: AppSpace.sm),
          filters,
        ] else
          Row(
            children: [
              Expanded(
                child: StudySearchField(
                  controller: controller,
                  hintText: 'Search this section',
                  onChanged: onSearch,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Flexible(child: filters),
            ],
          ),
      ],
    );
  }

  Widget _filterChip(String label, _LessonFilter value) {
    return FilterChip(
      label: Text(label),
      selected: filter == value,
      onSelected: (_) => onFilter(value),
    );
  }
}

class _LessonList extends StatefulWidget {
  const _LessonList({
    required this.database,
    required this.section,
    required this.query,
    required this.filter,
    required this.onOpen,
    required this.onCompletion,
    required this.onEditTitle,
  });

  final AppDatabase database;
  final Section section;
  final String query;
  final _LessonFilter filter;
  final ValueChanged<Item> onOpen;
  final void Function(Item item, bool completed) onCompletion;
  final ValueChanged<Item> onEditTitle;

  @override
  State<_LessonList> createState() => _LessonListState();
}

class _LessonListState extends State<_LessonList> {
  (int, String, String)? _after;
  final _previous = <(int, String, String)?>[];
  @override
  void didUpdateWidget(covariant _LessonList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.id != widget.section.id ||
        oldWidget.query != widget.query ||
        oldWidget.filter != widget.filter) {
      _after = null;
      _previous.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final database = widget.database,
        section = widget.section,
        query = widget.query,
        filter = widget.filter;
    final onOpen = widget.onOpen,
        onCompletion = widget.onCompletion,
        onEditTitle = widget.onEditTitle;
    return StudyPageTransition(
      selection: section.id,
      child: StreamBuilder<List<ItemProgressEntry>>(
        stream: database.watchItemProgressForSection(
          section.id,
          search: query,
          filter: filter.name,
          after: _after,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ContentState(
              icon: Icons.error_outline_rounded,
              title: 'Lessons could not load',
              message:
                  'This section is temporarily unavailable. Try again shortly.',
              tone: ContentStateTone.error,
              compact: true,
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ContentLoadingState(label: 'Loading lessons');
          }
          final all = snapshot.data ?? const [];
          if (all.isEmpty) {
            return Column(
              children: [
                const Expanded(
                  child: ContentState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'No matching lessons',
                    message: 'Try another search or progress filter.',
                    compact: true,
                  ),
                ),
                if (_previous.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _after = _previous.removeLast();
                    }),
                    child: const Text('Previous page'),
                  ),
              ],
            );
          }
          final entries = all.take(64).toList();
          return Column(
            children: [
              Expanded(
                child: StudySurface(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpace.xs),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const Divider(indent: 76, endIndent: AppSpace.sm),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _LessonRow(
                        index: index,
                        entry: entry,
                        onOpen: () => onOpen(entry.item),
                        onCompletion: (completed) =>
                            onCompletion(entry.item, completed),
                        onEditTitle: () => onEditTitle(entry.item),
                      );
                    },
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Page ${_previous.length + 1}'),
                  TextButton(
                    onPressed: _previous.isEmpty
                        ? null
                        : () => setState(() {
                            _after = _previous.removeLast();
                          }),
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: all.length <= 64
                        ? null
                        : () => setState(() {
                            final last = entries.last.item;
                            _previous.add(_after);
                            _after = (last.orderIndex, last.title, last.id);
                          }),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.index,
    required this.entry,
    required this.onOpen,
    required this.onCompletion,
    required this.onEditTitle,
  });

  final int index;
  final ItemProgressEntry entry;
  final VoidCallback onOpen;
  final ValueChanged<bool> onCompletion;
  final VoidCallback onEditTitle;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final title = cleanDisplayTitle(item.userTitle ?? item.title);
    final badge = item.unavailable
        ? const StudyStatusBadge(
            label: 'Missing file',
            icon: Icons.link_off_rounded,
            tone: StudyStatusTone.error,
          )
        : entry.completed
        ? const StudyStatusBadge(
            label: 'Complete',
            icon: Icons.check_rounded,
            tone: StudyStatusTone.success,
          )
        : entry.progressPercent > 0
        ? const StudyStatusBadge(
            label: 'In progress',
            icon: Icons.timelapse_rounded,
            tone: StudyStatusTone.info,
          )
        : const StudyStatusBadge(label: 'Not started');

    return Semantics(
      button: true,
      label:
          '$title, ${entry.completed ? 'complete' : '${entry.progressPercent.toStringAsFixed(0)} percent complete'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.unavailable
                      ? Theme.of(context).colorScheme.errorContainer
                      : context.studyColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: item.unavailable
                    ? Icon(
                        Icons.link_off_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      )
                    : Icon(
                        _icon(item.itemType),
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpace.xs),
                        badge,
                      ],
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    StudyMeta(
                      items: [
                        item.itemType.toUpperCase(),
                        if (item.durationSeconds != null &&
                            item.durationSeconds! > 0)
                          _formatDuration(item.durationSeconds!),
                        if (item.pageCount != null)
                          '${item.pageCount} ${item.pageCount == 1 ? 'page' : 'pages'}',
                        item.filename,
                      ],
                      maxLines: 1,
                    ),
                    if (!item.unavailable) ...[
                      const SizedBox(height: AppSpace.sm),
                      StudyProgress(
                        value: entry.progressPercent / 100,
                        label: 'Lesson progress',
                        height: 5,
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Tap to relink this lesson',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              PopupMenuButton<String>(
                tooltip: 'Lesson actions',
                onSelected: (value) {
                  if (value == 'edit') onEditTitle();
                  if (value == 'complete') onCompletion(true);
                  if (value == 'incomplete') onCompletion(false);
                  if (value == 'relink') onOpen();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit title'),
                    ),
                  ),
                  PopupMenuItem(
                    value: entry.completed ? 'incomplete' : 'complete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        entry.completed
                            ? Icons.radio_button_unchecked_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                      title: Text(
                        entry.completed ? 'Mark incomplete' : 'Mark complete',
                      ),
                    ),
                  ),
                  if (item.unavailable)
                    const PopupMenuItem(
                      value: 'relink',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.link_rounded),
                        title: Text('Relink file'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(String type) => switch (type) {
    'video' => Icons.play_circle_outline_rounded,
    'audio' => Icons.headphones_rounded,
    'pdf' => Icons.menu_book_rounded,
    'image' => Icons.image_outlined,
    'txt' => Icons.article_outlined,
    'html' || 'link' => Icons.language_rounded,
    _ => Icons.description_outlined,
  };

  static String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final remaining = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return duration.inHours > 0
        ? '${duration.inHours}:$minutes:$remaining'
        : '$minutes:$remaining';
  }
}
