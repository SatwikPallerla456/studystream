import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/indexer/library_indexer.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../library/library_creation.dart';
import '../library/library_scan_dialog.dart';
import '../../shared/widgets/media_categories.dart';
import '../../domain/services/media_import_service.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../shared/widgets/library_card.dart';
import '../../shared/widgets/study_shell.dart';
import '../../shared/widgets/study_ui.dart';
import '../../shared/widgets/study_motion.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../media/cinematic_home_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialDestination = 0});
  final int initialDestination;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _destination = widget.initialDestination;
  static const _tabs = ['home', 'libraries', 'search', 'settings'];

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDestination != widget.initialDestination) {
      _destination = widget.initialDestination;
    }
  }

  void _selectDestination(int value) {
    setState(() => _destination = value);
    context.go('/?tab=${_tabs[value]}');
  }

  bool _importing = false;

  static const _destinations = [
    StudyShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    StudyShellDestination(
      label: 'Libraries',
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library_rounded,
    ),
    StudyShellDestination(
      label: 'Search',
      icon: Icons.search_rounded,
      selectedIcon: Icons.manage_search_rounded,
    ),
    StudyShellDestination(
      label: 'Settings',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
    ),
  ];

  bool get _scanning => _importing;

  Future<void> _pickFiles() async {
    if (_scanning) return;
    setState(() => _importing = true);
    try {
      final result = await MediaImportService(
        ref.read(libraryIndexerProvider),
      ).pickFiles();
      if (mounted && result != null) {
        _showMessage(
          '${result.importedItems} media files are ready',
          success: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'The files could not be imported. Check access and available storage.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _pickFolder() => createMediaLibrary(context);

  Future<void> _removeLibrary(Library library) async {
    final confirmed = await showStudyAdaptiveModal<bool>(
      context: context,
      builder: (_) => StudyConfirmDialog(
        title: 'Remove this library?',
        message:
            '“${cleanDisplayTitle(library.title)}” and its Tangerine progress, notes, and bookmarks will be removed. Your source files will stay untouched.',
        confirmLabel: 'Remove library',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
    );
    if (confirmed != true) return;
    await ref.read(appDatabaseProvider).deleteLibraryCascade(library.id);
    if (mounted) {
      _showMessage('Library removed. Source files were not changed.');
    }
  }

  void _openItem(Item item) {
    context.push(MediaVisuals.route(item));
  }

  void _showMessage(
    String message, {
    bool error = false,
    bool success = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : success
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              color: colors.onInverseSurface,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    final pages = [
      _HomeDashboard(
        database: database,
        onAddLibrary: _pickFolder,
        onAddFiles: _scanning ? null : _pickFiles,
        onOpenItem: _openItem,
        onOpenLibraries: () => _selectDestination(1),
      ),
      _LibrariesPage(
        database: database,
        scanProgress: null,
        scanning: _scanning,
        onCancelScan: null,
        onAddLibrary: _pickFolder,
        onRescan: (library) => showLibraryScan(context, libraryId: library.id),
        onRemove: _removeLibrary,
      ),
      const SearchScreen(),
      const SettingsScreen(),
    ];

    return StudyShell(
      index: _destination,
      onDestinationSelected: _selectDestination,
      destinations: _destinations,
      child: StudyPageTransition(
        selection: _destination,
        child: IndexedStack(index: _destination, children: pages),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.database,
    required this.onAddLibrary,
    required this.onAddFiles,
    required this.onOpenItem,
    required this.onOpenLibraries,
  });

  final AppDatabase database;
  final VoidCallback onAddLibrary;
  final VoidCallback? onAddFiles;
  final ValueChanged<Item> onOpenItem;
  final VoidCallback onOpenLibraries;

  @override
  Widget build(BuildContext context) {
    return StudyPage(
      child: StreamBuilder<List<Library>>(
        stream: database.watchLibraries(),
        builder: (context, snapshot) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudyPageHeader(
                title: 'Home',
                actions: [
                  TextButton.icon(
                    onPressed: () => context.push('/browse'),
                    icon: const Icon(Icons.grid_view_outlined),
                    label: const Text('Browse all'),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Add media',
                    onSelected: (value) {
                      if (value == 'library') onAddLibrary();
                      if (value == 'files') onAddFiles?.call();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'library',
                        child: Text('Add library folder'),
                      ),
                      PopupMenuItem(
                        value: 'files',
                        enabled: onAddFiles != null,
                        child: const Text('Add files'),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 8),
                          Text('Add media'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              const Text('Browse by category'),
              const SizedBox(height: 12),
              const MediaCategories(compact: true),
              const SizedBox(height: 24),
              if (snapshot.hasError)
                ContentState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Your libraries are unavailable',
                  message:
                      'Tangerine could not load your local library index. Try reopening the app.',
                  tone: ContentStateTone.error,
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const ContentLoadingState(label: 'Loading your home screen')
              else if ((snapshot.data ?? const <Library>[]).isEmpty)
                _Onboarding(onAddLibrary: onAddLibrary)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CinematicHomeSection(onOpen: onOpenItem),
                    StudySectionHeader(
                      title: 'Libraries',
                      trailing: TextButton(
                        onPressed: onOpenLibraries,
                        child: const Text('View all'),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    _QuickLibraries(
                      database: database,
                      libraries: snapshot.data!.take(4).toList(),
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

class _Onboarding extends StatelessWidget {
  const _Onboarding({required this.onAddLibrary});

  final VoidCallback onAddLibrary;

  @override
  Widget build(BuildContext context) {
    return StudySurface(
      emphasized: true,
      padding: EdgeInsets.all(
        AppBreakpoints.isCompact(context) ? AppSpace.lg : AppSpace.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(
              Icons.video_library_rounded,
              size: 36,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'Your library starts here',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              'Add videos, music, PDFs, and other documents. Choose a folder to keep files in place, add files to copy them into the app, or connect to a media server through Network.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          FilledButton.icon(
            onPressed: onAddLibrary,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Add your first library'),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'No upload or account required',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _QuickLibraries extends StatelessWidget {
  const _QuickLibraries({required this.database, required this.libraries});

  final AppDatabase database;
  final List<Library> libraries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final library in libraries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: LibraryCard(
              library: library,
              stats: database.getLibraryStats(library.id),
              layout: LibraryCardLayout.list,
              onTap: () => context.push('/library/${library.id}'),
            ),
          ),
      ],
    );
  }
}

enum _LibrarySort { title, recentlyUpdated, recentlyAdded }

class _LibrariesPage extends StatefulWidget {
  const _LibrariesPage({
    required this.database,
    required this.scanProgress,
    required this.scanning,
    required this.onCancelScan,
    required this.onAddLibrary,
    required this.onRescan,
    required this.onRemove,
  });

  final AppDatabase database;
  final ScanProgress? scanProgress;
  final bool scanning;
  final VoidCallback? onCancelScan;
  final VoidCallback onAddLibrary;
  final ValueChanged<Library> onRescan;
  final ValueChanged<Library> onRemove;

  @override
  State<_LibrariesPage> createState() => _LibrariesPageState();
}

class _LibrariesPageState extends State<_LibrariesPage> {
  final _searchController = TextEditingController();
  _LibrarySort _sort = _LibrarySort.title;
  LibraryCardLayout _layout = LibraryCardLayout.list;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyPageHeader(
            title: 'Libraries',
            actions: [
              FilledButton.icon(
                onPressed: widget.scanning ? null : widget.onAddLibrary,
                icon: widget.scanning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(widget.scanning ? 'Scanning…' : 'Add library'),
              ),
            ],
          ),
          if (widget.scanProgress != null) ...[
            const SizedBox(height: AppSpace.lg),
            _ScanStatus(
              progress: widget.scanProgress!,
              onCancel: widget.onCancelScan,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Media categories',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const MediaCategories(),
          const SizedBox(height: 24),
          Text(
            'Source libraries',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _LibraryToolbar(
            controller: _searchController,
            sort: _sort,
            layout: _layout,
            onSearch: (_) => setState(() {}),
            onSort: (value) => setState(() => _sort = value),
            onLayout: (value) => setState(() => _layout = value),
          ),
          const SizedBox(height: AppSpace.lg),
          StreamBuilder<List<Library>>(
            stream: widget.database.watchLibraries(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const ContentState(
                  icon: Icons.folder_off_rounded,
                  title: 'Libraries could not load',
                  message:
                      'The local library index is temporarily unavailable. Your source files are not affected.',
                  tone: ContentStateTone.error,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ContentLoadingState(label: 'Loading libraries');
              }
              final libraries = _visible(snapshot.data ?? const []);
              if ((snapshot.data ?? const <Library>[]).isEmpty) {
                return ContentState(
                  icon: Icons.create_new_folder_outlined,
                  title: 'No libraries yet',
                  message:
                      'Choose a media folder to organise videos, music, documents, and courses without moving the files.',
                  action: FilledButton.icon(
                    onPressed: widget.onAddLibrary,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add your first library'),
                  ),
                );
              }
              if (libraries.isEmpty) {
                return ContentState(
                  icon: Icons.search_off_rounded,
                  title: 'No matching libraries',
                  message: 'Try a different name or clear the search.',
                  action: OutlinedButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: const Text('Clear search'),
                  ),
                );
              }
              return _LibraryCollection(
                database: widget.database,
                libraries: libraries,
                layout: _layout,
                scanning: widget.scanning,
                onRescan: widget.onRescan,
                onRemove: widget.onRemove,
              );
            },
          ),
        ],
      ),
    );
  }

  List<Library> _visible(List<Library> all) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = all
        .where(
          (library) =>
              query.isEmpty ||
              library.title.toLowerCase().contains(query) ||
              library.description.toLowerCase().contains(query),
        )
        .toList();
    switch (_sort) {
      case _LibrarySort.title:
        visible.sort(
          (a, b) => cleanDisplayTitle(
            a.title,
          ).toLowerCase().compareTo(cleanDisplayTitle(b.title).toLowerCase()),
        );
      case _LibrarySort.recentlyUpdated:
        visible.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _LibrarySort.recentlyAdded:
        visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return visible;
  }
}

class _LibraryToolbar extends StatelessWidget {
  const _LibraryToolbar({
    required this.controller,
    required this.sort,
    required this.layout,
    required this.onSearch,
    required this.onSort,
    required this.onLayout,
  });

  final TextEditingController controller;
  final _LibrarySort sort;
  final LibraryCardLayout layout;
  final ValueChanged<String> onSearch;
  final ValueChanged<_LibrarySort> onSort;
  final ValueChanged<LibraryCardLayout> onLayout;

  @override
  Widget build(BuildContext context) {
    final search = StudySearchField(
      controller: controller,
      hintText: 'Search libraries',
      onChanged: onSearch,
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<_LibrarySort>(
            isExpanded: true,
            initialValue: sort,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.xs,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: _LibrarySort.title,
                child: Text(
                  'Title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: _LibrarySort.recentlyUpdated,
                child: Text(
                  'Recently updated',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: _LibrarySort.recentlyAdded,
                child: Text(
                  'Recently added',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            selectedItemBuilder: (_) => const [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recently updated',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recently added',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) onSort(value);
            },
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        SegmentedButton<LibraryCardLayout>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: LibraryCardLayout.grid,
              icon: Icon(Icons.grid_view_rounded),
              tooltip: 'Grid view',
            ),
            ButtonSegment(
              value: LibraryCardLayout.list,
              icon: Icon(Icons.view_list_rounded),
              tooltip: 'List view',
            ),
          ],
          selected: {layout},
          onSelectionChanged: (value) => onLayout(value.first),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: AppSpace.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: controls,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: AppSpace.sm),
            controls,
          ],
        );
      },
    );
  }
}

class _LibraryCollection extends StatelessWidget {
  const _LibraryCollection({
    required this.database,
    required this.libraries,
    required this.layout,
    required this.scanning,
    required this.onRescan,
    required this.onRemove,
  });

  final AppDatabase database;
  final List<Library> libraries;
  final LibraryCardLayout layout;
  final bool scanning;
  final ValueChanged<Library> onRescan;
  final ValueChanged<Library> onRemove;

  @override
  Widget build(BuildContext context) {
    if (layout == LibraryCardLayout.list) {
      return Column(
        children: [
          for (var i = 0; i < libraries.length; i++) ...[
            LibraryCard(
              library: libraries[i],
              stats: database.getLibraryStats(libraries[i].id),
              layout: LibraryCardLayout.list,
              onTap: () => context.push('/library/${libraries[i].id}'),
              onRescan: scanning ? null : () => onRescan(libraries[i]),
              onRemove: () => onRemove(libraries[i]),
            ),
            if (i != libraries.length - 1) const SizedBox(height: AppSpace.sm),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 660
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: libraries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent:
                430 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 10,
            crossAxisSpacing: AppSpace.md,
            mainAxisSpacing: AppSpace.md,
          ),
          itemBuilder: (context, index) {
            final library = libraries[index];
            return LibraryCard(
              library: library,
              stats: database.getLibraryStats(library.id),
              onTap: () => context.push('/library/${library.id}'),
              onRescan: scanning ? null : () => onRescan(library),
              onRemove: () => onRemove(library),
            );
          },
        );
      },
    );
  }
}

class _ScanStatus extends StatelessWidget {
  const _ScanStatus({required this.progress, this.onCancel});

  final ScanProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final currentFile = progress.currentPath == null
        ? null
        : cleanDisplayTitle(p.basename(progress.currentPath!));
    return Semantics(
      liveRegion: true,
      label:
          '${progress.phase}, ${progress.processedFiles} of ${progress.discoveredFiles} files',
      child: StudySurface(
        selected: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              alignment: Alignment.center,
              child: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.phase,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  StudyProgress(
                    value: progress.fraction ?? 0,
                    label:
                        '${progress.processedFiles} of ${progress.discoveredFiles} files',
                    showPercentage: true,
                  ),
                  if (currentFile != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      currentFile,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}
