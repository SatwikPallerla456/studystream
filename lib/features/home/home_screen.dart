import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/indexer/library_indexer.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/continue_item_tile.dart';
import '../../shared/widgets/library_card.dart';
import '../../shared/widgets/study_shell.dart';
import '../../shared/widgets/study_ui.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../study/study_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _destination = 0;
  ScanProgress? _progress;
  ScanCancellationToken? _scanToken;

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
      label: 'Study',
      icon: Icons.auto_stories_outlined,
      selectedIcon: Icons.auto_stories_rounded,
    ),
    StudyShellDestination(
      label: 'Settings',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
    ),
  ];

  bool get _scanning => _scanToken != null;

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a course or library folder',
    );
    if (path == null || path.isEmpty) return;
    await _scan(path: path, title: cleanDisplayTitle(p.basename(path)));
  }

  Future<void> _scan({required String path, required String title}) async {
    final token = ScanCancellationToken();
    setState(() {
      _scanToken = token;
      _progress = const ScanProgress(
        phase: 'Preparing your library',
        discoveredFiles: 0,
        processedFiles: 0,
      );
    });
    try {
      final result = await ref
          .read(libraryIndexerProvider)
          .scanRootFolder(
            rootFolderPath: path,
            title: title,
            cancellationToken: token,
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          );
      if (!mounted) return;
      final detail = result.errors.isEmpty
          ? '${result.importedItems} lessons are ready'
          : '${result.importedItems} lessons added · ${result.errors.length} files need attention';
      _showMessage(detail, success: result.errors.isEmpty);
      context.push('/library/${result.libraryId}');
    } on ScanCancelledException {
      if (mounted) {
        _showMessage('Scan cancelled. Your existing library was kept.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'This folder could not be scanned. Check access and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _scanToken = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _removeLibrary(Library library) async {
    final confirmed = await showStudyAdaptiveModal<bool>(
      context: context,
      builder: (_) => StudyConfirmDialog(
        title: 'Remove this library?',
        message:
            '“${cleanDisplayTitle(library.title)}” and its StudyStream progress, notes, and bookmarks will be removed. Your source files will stay untouched.',
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
    final route = switch (item.itemType) {
      'video' || 'audio' => '/player/${item.id}',
      'pdf' => '/pdf/${item.id}',
      _ => '/resource/${item.id}',
    };
    context.push(route);
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
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    final pages = [
      _HomeDashboard(
        database: database,
        onAddLibrary: _pickFolder,
        onOpenItem: _openItem,
        onOpenLibraries: () => setState(() => _destination = 1),
      ),
      _LibrariesPage(
        database: database,
        scanProgress: _progress,
        scanning: _scanning,
        onCancelScan: _scanToken?.cancel,
        onAddLibrary: _pickFolder,
        onRescan: (library) =>
            _scan(path: library.rootFolderPath, title: library.title),
        onRemove: _removeLibrary,
      ),
      const SearchScreen(),
      const StudyScreen(),
      const SettingsScreen(),
    ];

    return StudyShell(
      index: _destination,
      onDestinationSelected: (value) => setState(() => _destination = value),
      destinations: _destinations,
      child: IndexedStack(index: _destination, children: pages),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.database,
    required this.onAddLibrary,
    required this.onOpenItem,
    required this.onOpenLibraries,
  });

  final AppDatabase database;
  final VoidCallback onAddLibrary;
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
                eyebrow: 'Your learning space',
                title: 'Welcome back',
                description:
                    'Continue a lesson, revisit a page, or settle into your next focused session.',
                actions: [
                  FilledButton.icon(
                    onPressed: onAddLibrary,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add library'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              if (snapshot.hasError)
                ContentState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Your libraries are unavailable',
                  message:
                      'StudyStream could not load your local library index. Try reopening the app.',
                  tone: ContentStateTone.error,
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const ContentLoadingState(label: 'Loading your home screen')
              else if ((snapshot.data ?? const <Library>[]).isEmpty)
                _Onboarding(onAddLibrary: onAddLibrary)
              else
                _PopulatedHome(
                  database: database,
                  libraries: snapshot.data!,
                  onAddLibrary: onAddLibrary,
                  onOpenItem: onOpenItem,
                  onOpenLibraries: onOpenLibraries,
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
            'Build your first learning library',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              'Choose a folder you already own. StudyStream organises videos, audio, PDFs, and reading files into sections without moving them.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final steps = [
                const _OnboardingStep(
                  number: '1',
                  title: 'Choose a folder',
                  description: 'Your original files remain in place.',
                ),
                const _OnboardingStep(
                  number: '2',
                  title: 'Let us organise it',
                  description: 'Nested folders become clear sections.',
                ),
                const _OnboardingStep(
                  number: '3',
                  title: 'Learn at your pace',
                  description: 'Progress, notes, and bookmarks stay private.',
                ),
              ];
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      steps[i],
                      if (i != steps.length - 1)
                        const SizedBox(height: AppSpace.sm),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Expanded(child: steps[i]),
                    if (i != steps.length - 1)
                      const SizedBox(width: AppSpace.sm),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpace.xl),
          FilledButton.icon(
            onPressed: onAddLibrary,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Choose your first folder'),
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

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: context.studyColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.studyColors.outlineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpace.xxs),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PopulatedHome extends StatelessWidget {
  const _PopulatedHome({
    required this.database,
    required this.libraries,
    required this.onAddLibrary,
    required this.onOpenItem,
    required this.onOpenLibraries,
  });

  final AppDatabase database;
  final List<Library> libraries;
  final VoidCallback onAddLibrary;
  final ValueChanged<Item> onOpenItem;
  final VoidCallback onOpenLibraries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LearningOverview(libraryCount: libraries.length),
        const SizedBox(height: AppSpace.xxl),
        const StudySectionHeader(
          title: 'Continue learning',
          description: 'Your most recent lessons, ready where you left them.',
        ),
        const SizedBox(height: AppSpace.md),
        _ContinueSection(database: database, onOpen: onOpenItem),
        const SizedBox(height: AppSpace.xxl),
        StudySectionHeader(
          title: 'Your libraries',
          description: 'Quick access to the collections you return to most.',
          trailing: TextButton.icon(
            onPressed: onOpenLibraries,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('View all'),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        _QuickLibraries(
          database: database,
          libraries: libraries.take(4).toList(),
        ),
      ],
    );
  }
}

class _LearningOverview extends StatelessWidget {
  const _LearningOverview({required this.libraryCount});

  final int libraryCount;

  @override
  Widget build(BuildContext context) {
    return StudySurface(
      emphasized: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StudyStatusBadge(
                label: 'Local & private',
                icon: Icons.lock_outline_rounded,
                tone: StudyStatusTone.success,
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'A calm place for focused learning',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                '$libraryCount ${libraryCount == 1 ? 'library is' : 'libraries are'} organised and ready on this device.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          );
          final mark = Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(
              Icons.slow_motion_video_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: AppSpace.lg),
                mark,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: AppSpace.lg),
              mark,
            ],
          );
        },
      ),
    );
  }
}

class _ContinueSection extends StatelessWidget {
  const _ContinueSection({required this.database, required this.onOpen});

  final AppDatabase database;
  final ValueChanged<Item> onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContinueEntry>>(
      stream: database.watchRecentPlaybackEntries(limit: 8),
      builder: (context, mediaSnapshot) {
        return StreamBuilder<List<ContinueEntry>>(
          stream: database.watchRecentReadingEntries(limit: 8),
          builder: (context, readingSnapshot) {
            if (mediaSnapshot.hasError || readingSnapshot.hasError) {
              return const ContentState(
                icon: Icons.history_toggle_off_rounded,
                title: 'Recent activity is unavailable',
                message:
                    'Your library is safe. Reopen this screen to try again.',
                tone: ContentStateTone.error,
                compact: true,
              );
            }
            if (mediaSnapshot.connectionState == ConnectionState.waiting ||
                readingSnapshot.connectionState == ConnectionState.waiting) {
              return const ContentLoadingState(label: 'Loading recent lessons');
            }
            final entries = [...?mediaSnapshot.data, ...?readingSnapshot.data]
              ..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
            if (entries.isEmpty) {
              return const ContentState(
                icon: Icons.play_circle_outline_rounded,
                title: 'Your next session starts here',
                message:
                    'Open any lesson and it will return here at the exact moment or page you reached.',
                compact: true,
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1040 ? 2 : 1;
                final visible = entries.take(6).toList();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visible.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 124,
                    crossAxisSpacing: AppSpace.sm,
                    mainAxisSpacing: AppSpace.sm,
                  ),
                  itemBuilder: (context, index) => ContinueItemTile(
                    entry: visible[index],
                    onTap: () => onOpen(visible[index].item),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _QuickLibraries extends StatelessWidget {
  const _QuickLibraries({required this.database, required this.libraries});

  final AppDatabase database;
  final List<Library> libraries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: libraries.length.clamp(0, columns == 3 ? 3 : 4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 390,
            crossAxisSpacing: AppSpace.sm,
            mainAxisSpacing: AppSpace.sm,
          ),
          itemBuilder: (context, index) {
            final library = libraries[index];
            return LibraryCard(
              library: library,
              stats: database.getLibraryStats(library.id),
              onTap: () => context.push('/library/${library.id}'),
            );
          },
        );
      },
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
  LibraryCardLayout _layout = LibraryCardLayout.grid;

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
            eyebrow: 'Collections',
            title: 'Libraries',
            description:
                'Organise the course folders already on your device and keep every lesson easy to find.',
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
          const SizedBox(height: AppSpace.xl),
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
                      'Choose a course folder and StudyStream will organise its lessons without moving the files.',
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
            mainAxisExtent: 390,
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
