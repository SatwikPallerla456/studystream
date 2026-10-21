import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/study_animated_list.dart';
import '../../shared/widgets/study_ui.dart';

enum _StudyKind { all, timed, pages, general }

enum _StudySort { updated, created, location }

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  final _searchController = TextEditingController();
  final Map<String, Future<_EntryContext>> _contextCache = {};
  int _tab = 0;
  String? _libraryId;
  String? _sectionId;
  String? _itemId;
  List<Section> _sections = const [];
  List<Item> _items = const [];
  _StudyKind _kind = _StudyKind.all;
  _StudySort _sort = _StudySort.updated;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectLibrary(AppDatabase database, String? libraryId) async {
    setState(() {
      _libraryId = libraryId;
      _sectionId = null;
      _itemId = null;
      _sections = const [];
      _items = const [];
    });
    if (libraryId == null) return;
    final sections = await database.getSectionsForLibrary(libraryId);
    final items = await database.getItemsForLibrary(libraryId);
    if (!mounted || _libraryId != libraryId) return;
    setState(() {
      _sections = sections;
      _items = items;
    });
  }

  Future<_EntryContext> _entryContext(
    AppDatabase database,
    String libraryId,
    String? itemId,
  ) {
    final key = '$libraryId:${itemId ?? 'general'}';
    return _contextCache.putIfAbsent(key, () async {
      final library = await database.getLibraryById(libraryId);
      if (itemId == null) {
        return _EntryContext(
          libraryTitle: library?.title ?? 'Unknown library',
          sectionTitle: 'General',
          itemTitle: 'Library note',
          item: null,
        );
      }
      final item = await database.getItemById(itemId);
      if (item == null) {
        return _EntryContext(
          libraryTitle: library?.title ?? 'Unknown library',
          sectionTitle: 'Missing section',
          itemTitle: 'Missing item',
          item: null,
        );
      }
      final sections = await database.getSectionsForLibrary(libraryId);
      Section? section;
      for (final candidate in sections) {
        if (candidate.id == item.sectionId) {
          section = candidate;
          break;
        }
      }
      return _EntryContext(
        libraryTitle: library?.title ?? 'Unknown library',
        sectionTitle: section?.title ?? 'Unknown section',
        itemTitle: item.userTitle ?? item.title,
        item: item,
      );
    });
  }

  Future<void> _editNote(AppDatabase database, Note note) async {
    final controller = TextEditingController(text: note.content);
    var valid = controller.text.trim().isNotEmpty;
    final result = await showStudyAdaptiveModal<String>(
      context: context,
      disposeOnClose: [controller],
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => StudyModalFrame(
          title: 'Edit note',
          description:
              'This note stays linked to ${_location(note.positionSeconds, note.pageNumber).toLowerCase()}.',
          icon: Icons.edit_note_rounded,
          primaryAction: FilledButton(
            onPressed: valid
                ? () => Navigator.pop(modalContext, controller.text.trim())
                : null,
            child: const Text('Save note'),
          ),
          secondaryAction: TextButton(
            onPressed: () => Navigator.pop(modalContext),
            child: const Text('Cancel'),
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: 'Note',
              alignLabelWithHint: true,
              errorText: valid ? null : 'A note cannot be empty',
            ),
            onChanged: (value) =>
                setModalState(() => valid = value.trim().isNotEmpty),
          ),
        ),
      ),
    );

    if (result == null) return;
    await database.upsertNote(
      note
          .copyWith(
            content: result,
            deviceId: await database.getDeviceId(),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            version: note.version + 1,
          )
          .toCompanion(true),
    );
    if (mounted) _message('Note updated');
  }

  Future<void> _editBookmark(AppDatabase database, Bookmark bookmark) async {
    final titleController = TextEditingController(text: bookmark.title);
    final descriptionController = TextEditingController(
      text: bookmark.description ?? '',
    );
    var valid = titleController.text.trim().isNotEmpty;
    final result =
        await showStudyAdaptiveModal<({String title, String? description})>(
          context: context,
          disposeOnClose: [titleController, descriptionController],
          builder: (modalContext) => StatefulBuilder(
            builder: (context, setModalState) => StudyModalFrame(
              title: 'Edit bookmark',
              description:
                  'Keep the title short and add context when it will help later.',
              icon: Icons.bookmark_outline_rounded,
              primaryAction: FilledButton(
                onPressed: valid
                    ? () {
                        final description = descriptionController.text.trim();
                        Navigator.pop(modalContext, (
                          title: titleController.text.trim(),
                          description: description.isEmpty ? null : description,
                        ));
                      }
                    : null,
                child: const Text('Save bookmark'),
              ),
              secondaryAction: TextButton(
                onPressed: () => Navigator.pop(modalContext),
                child: const Text('Cancel'),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      errorText: valid ? null : 'Enter a bookmark title',
                    ),
                    onChanged: (value) =>
                        setModalState(() => valid = value.trim().isNotEmpty),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: descriptionController,
                    minLines: 3,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    if (result == null) return;
    await database.upsertBookmark(
      bookmark
          .copyWith(
            title: result.title,
            deviceId: await database.getDeviceId(),
            description: drift.Value(result.description),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            version: bookmark.version + 1,
          )
          .toCompanion(true),
    );
    if (mounted) _message('Bookmark updated');
  }

  Future<void> _deleteNote(AppDatabase database, Note note) async {
    final confirmed = await showStudyAdaptiveModal<bool>(
      context: context,
      builder: (_) => const StudyConfirmDialog(
        title: 'Delete this note?',
        message: 'This note will be removed from Notes & bookmarks.',
        confirmLabel: 'Delete note',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
    );
    if (confirmed == true) {
      await database.deleteNoteSoft(note.id);
      if (mounted) _message('Note deleted');
    }
  }

  Future<void> _deleteBookmark(AppDatabase database, Bookmark bookmark) async {
    final confirmed = await showStudyAdaptiveModal<bool>(
      context: context,
      builder: (_) => const StudyConfirmDialog(
        title: 'Delete this bookmark?',
        message: 'This saved location will be removed from Notes & bookmarks.',
        confirmLabel: 'Delete bookmark',
        icon: Icons.bookmark_remove_outlined,
        destructive: true,
      ),
    );
    if (confirmed == true) {
      await database.deleteBookmarkSoft(bookmark.id);
      if (mounted) _message('Bookmark deleted');
    }
  }

  Future<void> _openItem(
    AppDatabase database,
    String itemId, {
    double? positionSeconds,
    int? pageNumber,
  }) async {
    final item = await database.getItemById(itemId);
    if (!mounted) return;
    if (item == null || item.unavailable) {
      _message('This lesson file is unavailable. Relink it from the library.');
      return;
    }
    final path = switch (item.itemType) {
      'video' || 'audio' => Uri(
        path: '/player/${item.id}',
        queryParameters: positionSeconds == null
            ? null
            : {'position': positionSeconds.toString()},
      ).toString(),
      'epub' || 'cbz' => Uri(
        path: '/book/${Uri.encodeComponent(item.id)}',
        queryParameters: pageNumber == null
            ? null
            : {'page': pageNumber.toString()},
      ).toString(),
      'pdf' => Uri(
        path: '/pdf/${item.id}',
        queryParameters: pageNumber == null
            ? null
            : {'page': pageNumber.toString()},
      ).toString(),
      _ => '/resource/${item.id}',
    };
    context.push(path);
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    return StreamBuilder<List<Library>>(
      stream: database.watchLibraries(),
      builder: (context, librarySnapshot) {
        final libraries = librarySnapshot.data ?? const <Library>[];
        return StudyPage(
          maxWidth: 1180,
          scrollable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StudyPageHeader(title: 'Notes & bookmarks'),
              const SizedBox(height: AppSpace.lg),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.notes_rounded),
                      label: Text('Notes'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.bookmarks_outlined),
                      label: Text('Bookmarks'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (value) =>
                      setState(() => _tab = value.first),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              StudySearchField(
                controller: _searchController,
                hintText: _tab == 0 ? 'Search notes' : 'Search bookmarks',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpace.sm),
              _StudyFilters(
                database: database,
                libraries: libraries,
                libraryId: _libraryId,
                sectionId: _sectionId,
                itemId: _itemId,
                sections: _sections,
                items: _items,
                kind: _kind,
                sort: _sort,
                onLibrary: (value) => _selectLibrary(database, value),
                onSection: (value) => setState(() {
                  _sectionId = value;
                  _itemId = null;
                }),
                onItem: (value) => setState(() => _itemId = value),
                onKind: (value) => setState(() => _kind = value),
                onSort: (value) => setState(() => _sort = value),
              ),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: _tab == 0
                    ? StreamBuilder<List<Note>>(
                        stream: database.watchNotes(),
                        builder: (context, snapshot) =>
                            _notes(database, snapshot, libraries: libraries),
                      )
                    : StreamBuilder<List<Bookmark>>(
                        stream: database.watchBookmarks(),
                        builder: (context, snapshot) => _bookmarks(
                          database,
                          snapshot,
                          libraries: libraries,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _notes(
    AppDatabase database,
    AsyncSnapshot<List<Note>> snapshot, {
    required List<Library> libraries,
  }) {
    if (snapshot.hasError) {
      return const ContentState(
        icon: Icons.error_outline_rounded,
        title: 'Notes could not load',
        message:
            'Your saved notes are temporarily unavailable. Try again shortly.',
        tone: ContentStateTone.error,
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const ContentLoadingState(label: 'Loading notes');
    }
    final notes = snapshot.data ?? const [];
    final visible = _filterNotes(notes);
    final emptyState = notes.isEmpty
        ? const ContentState(
            icon: Icons.note_add_outlined,
            title: 'Your notes will collect here',
            message:
                'Add notes while reading a book or document, or studying a course.',
          )
        : const ContentState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No matching notes',
            message: 'Try another search, location type, or library filter.',
          );
    return StudyAnimatedList<Note>(
      key: const ValueKey('study-notes'),
      items: visible,
      itemId: (note) => note.id,
      emptyState: emptyState,
      padding: const EdgeInsets.all(AppSpace.xs),
      separatorBuilder: (_, _) =>
          const Divider(indent: 76, endIndent: AppSpace.sm),
      listBuilder: (_, child) =>
          StudySurface(padding: EdgeInsets.zero, child: child),
      itemBuilder: (context, note) {
        return _StudyEntryRow(
          icon: Icons.notes_rounded,
          tone: StudyStatusTone.info,
          typeLabel: 'Note',
          title: note.content,
          location: _location(note.positionSeconds, note.pageNumber),
          updatedAt: note.updatedAt,
          contextFuture: _entryContext(database, note.libraryId, note.itemId),
          onOpen: note.itemId == null
              ? null
              : () => _openItem(
                  database,
                  note.itemId!,
                  positionSeconds: note.positionSeconds,
                  pageNumber: note.pageNumber,
                ),
          onEdit: () => _editNote(database, note),
          onDelete: () => _deleteNote(database, note),
        );
      },
    );
  }

  Widget _bookmarks(
    AppDatabase database,
    AsyncSnapshot<List<Bookmark>> snapshot, {
    required List<Library> libraries,
  }) {
    if (snapshot.hasError) {
      return const ContentState(
        icon: Icons.error_outline_rounded,
        title: 'Bookmarks could not load',
        message:
            'Your saved locations are temporarily unavailable. Try again shortly.',
        tone: ContentStateTone.error,
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const ContentLoadingState(label: 'Loading bookmarks');
    }
    final bookmarks = snapshot.data ?? const [];
    final visible = _filterBookmarks(bookmarks);
    final emptyState = bookmarks.isEmpty
        ? const ContentState(
            icon: Icons.bookmark_add_outlined,
            title: 'No bookmarks yet',
            message:
                'Save a page in a reader or a moment in a course to find it here.',
          )
        : const ContentState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No matching bookmarks',
            message: 'Try another search, location type, or library filter.',
          );
    return StudyAnimatedList<Bookmark>(
      key: const ValueKey('study-bookmarks'),
      items: visible,
      itemId: (bookmark) => bookmark.id,
      emptyState: emptyState,
      padding: const EdgeInsets.all(AppSpace.xs),
      separatorBuilder: (_, _) =>
          const Divider(indent: 76, endIndent: AppSpace.sm),
      listBuilder: (_, child) =>
          StudySurface(padding: EdgeInsets.zero, child: child),
      itemBuilder: (context, bookmark) {
        return _StudyEntryRow(
          icon: Icons.bookmark_rounded,
          tone: StudyStatusTone.warning,
          typeLabel: 'Bookmark',
          title: bookmark.title,
          description: bookmark.description,
          location: _location(bookmark.positionSeconds, bookmark.pageNumber),
          updatedAt: bookmark.updatedAt,
          contextFuture: _entryContext(
            database,
            bookmark.libraryId,
            bookmark.itemId,
          ),
          onOpen: () => _openItem(
            database,
            bookmark.itemId,
            positionSeconds: bookmark.positionSeconds,
            pageNumber: bookmark.pageNumber,
          ),
          onEdit: () => _editBookmark(database, bookmark),
          onDelete: () => _deleteBookmark(database, bookmark),
        );
      },
    );
  }

  List<Note> _filterNotes(List<Note> notes) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = notes.where((note) {
      return (_libraryId == null || note.libraryId == _libraryId) &&
          _matchesItem(note.itemId) &&
          _matchesKind(note.positionSeconds, note.pageNumber) &&
          (query.isEmpty || note.content.toLowerCase().contains(query));
    }).toList();
    switch (_sort) {
      case _StudySort.updated:
        visible.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _StudySort.created:
        visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _StudySort.location:
        visible.sort(
          (a, b) => _locationValue(
            a.positionSeconds,
            a.pageNumber,
          ).compareTo(_locationValue(b.positionSeconds, b.pageNumber)),
        );
    }
    return visible;
  }

  List<Bookmark> _filterBookmarks(List<Bookmark> bookmarks) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = bookmarks.where((bookmark) {
      return (_libraryId == null || bookmark.libraryId == _libraryId) &&
          _matchesItem(bookmark.itemId) &&
          _matchesKind(bookmark.positionSeconds, bookmark.pageNumber) &&
          (query.isEmpty ||
              bookmark.title.toLowerCase().contains(query) ||
              (bookmark.description ?? '').toLowerCase().contains(query));
    }).toList();
    switch (_sort) {
      case _StudySort.updated:
        visible.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _StudySort.created:
        visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _StudySort.location:
        visible.sort(
          (a, b) => _locationValue(
            a.positionSeconds,
            a.pageNumber,
          ).compareTo(_locationValue(b.positionSeconds, b.pageNumber)),
        );
    }
    return visible;
  }

  bool _matchesItem(String? itemId) {
    if (_itemId != null) return itemId == _itemId;
    if (_sectionId == null) return true;
    return _items.any(
      (item) => item.id == itemId && item.sectionId == _sectionId,
    );
  }

  bool _matchesKind(double? position, int? page) => switch (_kind) {
    _StudyKind.all => true,
    _StudyKind.timed => position != null,
    _StudyKind.pages => page != null,
    _StudyKind.general => position == null && page == null,
  };

  static double _locationValue(double? position, int? page) =>
      page?.toDouble() ?? position ?? -1;

  static String _location(double? position, int? page) {
    if (page != null) return 'Page $page';
    if (position != null) {
      final duration = Duration(seconds: position.round());
      final minutes = duration.inMinutes
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      final seconds = duration.inSeconds
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      return duration.inHours > 0
          ? '${duration.inHours}:$minutes:$seconds'
          : '$minutes:$seconds';
    }
    return 'General note';
  }
}

class _StudyFilters extends StatelessWidget {
  const _StudyFilters({
    required this.database,
    required this.libraries,
    required this.libraryId,
    required this.sectionId,
    required this.itemId,
    required this.sections,
    required this.items,
    required this.kind,
    required this.sort,
    required this.onLibrary,
    required this.onSection,
    required this.onItem,
    required this.onKind,
    required this.onSort,
  });

  final AppDatabase database;
  final List<Library> libraries;
  final String? libraryId;
  final String? sectionId;
  final String? itemId;
  final List<Section> sections;
  final List<Item> items;
  final _StudyKind kind;
  final _StudySort sort;
  final ValueChanged<String?> onLibrary;
  final ValueChanged<String?> onSection;
  final ValueChanged<String?> onItem;
  final ValueChanged<_StudyKind> onKind;
  final ValueChanged<_StudySort> onSort;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final width = compact ? constraints.maxWidth : 210.0;
        final sectionItems = sectionId == null
            ? items
            : items.where((item) => item.sectionId == sectionId).toList();
        return SingleChildScrollView(
          scrollDirection: compact ? Axis.horizontal : Axis.vertical,
          child: Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String>(
                  initialValue: libraryId ?? '__all__',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Library'),
                  items: [
                    const DropdownMenuItem(
                      value: '__all__',
                      child: Text('All libraries'),
                    ),
                    for (final library in libraries)
                      DropdownMenuItem(
                        value: library.id,
                        child: Text(
                          cleanDisplayTitle(library.title),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      onLibrary(value == '__all__' ? null : value),
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String>(
                  initialValue: sectionId ?? '__all__',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: [
                    const DropdownMenuItem(
                      value: '__all__',
                      child: Text('All sections'),
                    ),
                    for (final section in sections)
                      DropdownMenuItem(
                        value: section.id,
                        child: Text(
                          cleanDisplayTitle(section.title),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: libraryId == null
                      ? null
                      : (value) => onSection(value == '__all__' ? null : value),
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String>(
                  initialValue: itemId ?? '__all__',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                  items: [
                    const DropdownMenuItem(
                      value: '__all__',
                      child: Text('All titles'),
                    ),
                    for (final item in sectionItems)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          cleanDisplayTitle(item.userTitle ?? item.title),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: libraryId == null
                      ? null
                      : (value) => onItem(value == '__all__' ? null : value),
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<_StudyKind>(
                  isExpanded: true,
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Location type'),
                  items: const [
                    DropdownMenuItem(
                      value: _StudyKind.all,
                      child: Text('All locations'),
                    ),
                    DropdownMenuItem(
                      value: _StudyKind.timed,
                      child: Text('Media moments'),
                    ),
                    DropdownMenuItem(
                      value: _StudyKind.pages,
                      child: Text('Document pages'),
                    ),
                    DropdownMenuItem(
                      value: _StudyKind.general,
                      child: Text('General'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onKind(value);
                  },
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<_StudySort>(
                  isExpanded: true,
                  initialValue: sort,
                  decoration: const InputDecoration(labelText: 'Sort by'),
                  items: const [
                    DropdownMenuItem(
                      value: _StudySort.updated,
                      child: Text('Recently updated'),
                    ),
                    DropdownMenuItem(
                      value: _StudySort.created,
                      child: Text('Recently created'),
                    ),
                    DropdownMenuItem(
                      value: _StudySort.location,
                      child: Text('Location'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSort(value);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudyEntryRow extends StatelessWidget {
  const _StudyEntryRow({
    required this.icon,
    required this.tone,
    required this.typeLabel,
    required this.title,
    required this.location,
    required this.updatedAt,
    required this.contextFuture,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.description,
  });

  final IconData icon;
  final StudyStatusTone tone;
  final String typeLabel;
  final String title;
  final String? description;
  final String location;
  final int updatedAt;
  final Future<_EntryContext> contextFuture;
  final VoidCallback? onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tone == StudyStatusTone.warning
                  ? context.studyColors.warningContainer
                  : context.studyColors.infoContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: tone == StudyStatusTone.warning
                  ? context.studyColors.warning
                  : context.studyColors.info,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudyStatusBadge(label: typeLabel, icon: icon, tone: tone),
                const SizedBox(height: AppSpace.xs),
                Text(
                  title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpace.xs),
                FutureBuilder<_EntryContext>(
                  future: contextFuture,
                  builder: (context, snapshot) {
                    final value = snapshot.data;
                    if (value == null) {
                      return const StudySkeleton(width: 300, height: 13);
                    }
                    return StudyMeta(
                      items: [
                        cleanDisplayTitle(value.libraryTitle),
                        cleanDisplayTitle(value.sectionTitle),
                        cleanDisplayTitle(value.itemTitle),
                        location,
                        'Updated ${_relativeTime(updatedAt)}',
                      ],
                      maxLines: 2,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          PopupMenuButton<String>(
            tooltip: '$typeLabel actions',
            onSelected: (value) {
              if (value == 'open') onOpen?.call();
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'open',
                enabled: onOpen != null,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.open_in_new_rounded),
                  title: Text('Jump to content'),
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
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

class _EntryContext {
  const _EntryContext({
    required this.libraryTitle,
    required this.sectionTitle,
    required this.itemTitle,
    required this.item,
  });

  final String libraryTitle;
  final String sectionTitle;
  final String itemTitle;
  final Item? item;
}
