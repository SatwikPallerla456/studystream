import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../domain/reader/reader_contract.dart';
import '../../domain/study/study_catalog_repository.dart';
import 'content_state.dart';
import 'study_animated_list.dart';
import 'study_ui.dart';

Future<void> showLessonToolsSheet({
  required BuildContext context,
  required AppDatabase database,
  required Item item,
  String title = 'Notes & bookmarks',
  double? currentPositionSeconds,
  int? currentPage,
  ReaderLocator? anchor,
  ReaderTextAnchor? textAnchor,
  ValueChanged<ReaderTextAnchor>? onJumpToTextAnchor,
  ValueChanged<ReaderLocator>? onJumpToAnchor,
  String? selectedText,
  ValueChanged<double>? onJumpToPosition,
  ValueChanged<int>? onJumpToPage,
}) {
  return showStudyAdaptiveModal<void>(
    context: context,
    builder: (_) => LessonToolsSheet(
      database: database,
      item: item,
      title: title,
      currentPositionSeconds: currentPositionSeconds,
      currentPage: currentPage,
      anchor: anchor,
      textAnchor: textAnchor,
      onJumpToTextAnchor: onJumpToTextAnchor,
      onJumpToAnchor: onJumpToAnchor,
      selectedText: selectedText,
      onJumpToPosition: onJumpToPosition,
      onJumpToPage: onJumpToPage,
    ),
  );
}

class LessonToolsSheet extends StatefulWidget {
  const LessonToolsSheet({
    super.key,
    required this.database,
    required this.item,
    this.title = 'Notes & bookmarks',
    this.currentPositionSeconds,
    this.currentPage,
    this.anchor,
    this.textAnchor,
    this.onJumpToTextAnchor,
    this.onJumpToAnchor,
    this.selectedText,
    this.onJumpToPosition,
    this.onJumpToPage,
  });

  final AppDatabase database;
  final Item item;
  final String title;
  final double? currentPositionSeconds;
  final int? currentPage;
  final ReaderLocator? anchor;
  final ReaderTextAnchor? textAnchor;
  final ValueChanged<ReaderTextAnchor>? onJumpToTextAnchor;
  final ValueChanged<ReaderLocator>? onJumpToAnchor;
  final String? selectedText;
  final ValueChanged<double>? onJumpToPosition;
  final ValueChanged<int>? onJumpToPage;

  @override
  State<LessonToolsSheet> createState() => _LessonToolsSheetState();
}

class _LessonToolsSheetState extends State<LessonToolsSheet> {
  int _tab = 0;
  final _search = TextEditingController();
  final _cursors = <String?>[null, null];
  final _history = [<String?>[], <String?>[]];
  String _query = '';
  StudyCatalogRepository get _catalog =>
      StudyCatalogRepository(widget.database);
  late final _pages = <Stream<StudyPageResult>>[_watchPage(0), _watchPage(1)];
  Stream<StudyPageResult> _watchPage(int tab) => _catalog.watch(
    widget.item,
    tab == 0 ? StudyKind.notes : StudyKind.bookmarks,
    query: _query,
    cursor: _cursors[tab],
  );
  void _firstPages() => setState(() {
    for (var tab = 0; tab < 2; tab++) {
      _cursors[tab] = null;
      _history[tab].clear();
      _pages[tab] = _watchPage(tab);
    }
  });
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _pager(int tab, StudyPageResult page) => Row(
    children: [
      TextButton(
        onPressed: _history[tab].isEmpty
            ? null
            : () => setState(() {
                _cursors[tab] = _history[tab].removeLast();
                _pages[tab] = _watchPage(tab);
              }),
        child: const Text('Previous'),
      ),
      Text('Page ${_history[tab].length + 1}'),
      TextButton(
        onPressed: page.next == null
            ? null
            : () => setState(() {
                _history[tab].add(_cursors[tab]);
                _cursors[tab] = page.next;
                _pages[tab] = _watchPage(tab);
              }),
        child: const Text('Next'),
      ),
    ],
  );
  bool _useSelection = true;
  int? get _anchorPage => _useSelection && widget.textAnchor != null
      ? widget.textAnchor!.startPage
      : widget.currentPage;

  Future<String?> _askForText({
    required String title,
    String initial = '',
    String label = 'Text',
  }) async {
    final controller = TextEditingController(text: initial);
    var valid = controller.text.trim().isNotEmpty;
    final result = await showStudyAdaptiveModal<String>(
      context: context,
      disposeOnClose: [controller],
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => StudyModalFrame(
          title: title,
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
            maxLength: 100000,
            decoration: InputDecoration(
              labelText: label,
              alignLabelWithHint: true,
              errorText: valid ? null : 'A note cannot be empty',
            ),
            onChanged: (value) =>
                setModalState(() => valid = value.trim().isNotEmpty),
          ),
        ),
      ),
    );

    return result;
  }

  Future<void> _addNote() async {
    final content = await _askForText(
      title: 'Add note',
      label: 'Note',
      initial: widget.selectedText ?? '',
    );
    if (content == null || content.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const Uuid().v4();
    await widget.database.transaction(() async {
      await widget.database.upsertNote(
        NotesCompanion.insert(
          id: id,
          libraryId: widget.item.libraryId,
          itemId: drift.Value(widget.item.id),
          content: content,
          positionSeconds: drift.Value(widget.currentPositionSeconds),
          pageNumber: drift.Value(_anchorPage),
          createdAt: now,
          updatedAt: now,
          deviceId: await widget.database.getDeviceId(),
        ),
      );
      await _saveAnchor(id, note: true);
    });
    if (mounted) _firstPages();
  }

  Future<void> _saveAnchor(String id, {required bool note}) async {
    final source = widget.anchor;
    if (source == null) return;
    final range = _useSelection ? widget.textAnchor : null;
    if (range != null &&
        (!range.compatible(source.resourceId, source.revision) ||
            ReaderTextAnchor.decode(range.toJson()) == null))
      throw const FormatException('Invalid Study passage');
    final anchor = range != null
        ? ReaderLocator(
            resourceId: source.resourceId,
            revision: source.revision,
            pageKey: range.startKey,
            page: range.startPage,
            textOffset: range.startOffset,
            point: range.startPage == source.page ? source.point : Offset.zero,
            fit: source.fit,
            zoom: source.zoom,
          )
        : ReaderLocator(
            resourceId: source.resourceId,
            revision: source.revision,
            pageKey: source.pageKey,
            page: source.page,
            point: source.point,
            fit: source.fit,
            zoom: source.zoom,
          );
    if (anchor.resourceId != widget.item.id)
      throw const FormatException('Study anchor belongs to a different item');
    await widget.database.customStatement(
      'INSERT INTO study_anchors(id,library_id,item_id,note_id,bookmark_id,payload,updated_at) VALUES(?,?,?,?,?,?,?)',
      [
        '${note ? 'note' : 'bookmark'}:$id',
        widget.item.libraryId,
        widget.item.id,
        note ? id : null,
        note ? null : id,
        jsonEncode({
          'kind': range != null
              ? 'textRange'
              : anchor.textOffset == null
              ? 'page'
              : 'text',
          if (range != null) 'textRange': range.toJson(),
          'locator': anchor.encode(),
          if (widget.selectedText != null) 'text': widget.selectedText,
          if (anchor.textOffset != null) 'offset': anchor.textOffset,
        }),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> _editNote(Note note) async {
    final content = await _askForText(
      title: 'Edit note',
      label: 'Note',
      initial: note.content,
    );
    if (content == null || content.isEmpty) return;
    await widget.database.upsertNote(
      note
          .copyWith(
            content: content,
            deviceId: await widget.database.getDeviceId(),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            version: note.version + 1,
          )
          .toCompanion(true),
    );
  }

  Future<void> _addBookmark() async {
    final value = await _askForBookmark(
      title: 'Add bookmark',
      initialTitle: _defaultBookmarkTitle(),
    );
    if (value == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const Uuid().v4();
    await widget.database.transaction(() async {
      await widget.database.upsertBookmark(
        BookmarksCompanion.insert(
          id: id,
          libraryId: widget.item.libraryId,
          itemId: widget.item.id,
          title: value.title,
          description: drift.Value(value.description),
          positionSeconds: drift.Value(widget.currentPositionSeconds),
          pageNumber: drift.Value(_anchorPage),
          createdAt: now,
          updatedAt: now,
          deviceId: await widget.database.getDeviceId(),
        ),
      );
      await _saveAnchor(id, note: false);
    });
    if (mounted) _firstPages();
  }

  Future<void> _editBookmark(Bookmark bookmark) async {
    final value = await _askForBookmark(
      title: 'Edit bookmark',
      initialTitle: bookmark.title,
      initialDescription: bookmark.description ?? '',
    );
    if (value == null) return;
    await widget.database.upsertBookmark(
      bookmark
          .copyWith(
            title: value.title,
            deviceId: await widget.database.getDeviceId(),
            description: drift.Value(value.description),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            version: bookmark.version + 1,
          )
          .toCompanion(true),
    );
  }

  Future<({String title, String? description})?> _askForBookmark({
    required String title,
    required String initialTitle,
    String initialDescription = '',
  }) async {
    final titleController = TextEditingController(text: initialTitle);
    final descriptionController = TextEditingController(
      text: initialDescription,
    );
    var valid = titleController.text.trim().isNotEmpty;
    final result =
        await showStudyAdaptiveModal<({String title, String? description})>(
          context: context,
          disposeOnClose: [titleController, descriptionController],
          builder: (modalContext) => StatefulBuilder(
            builder: (context, setModalState) => StudyModalFrame(
              title: title,
              description: 'Save this exact moment or page for later.',
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
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
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
          ),
        );

    return result;
  }

  String _defaultBookmarkTitle() {
    if (widget.currentPage != null) return 'Page ${widget.currentPage}';
    if (widget.currentPositionSeconds != null) {
      return _formatDuration(widget.currentPositionSeconds!);
    }
    return cleanDisplayTitle(widget.item.title);
  }

  Future<void> _jump({double? position, int? page, String? anchorId}) async {
    if (anchorId != null &&
        (widget.onJumpToAnchor != null || widget.onJumpToTextAnchor != null)) {
      final row = await widget.database
          .customSelect(
            'SELECT payload FROM study_anchors WHERE id=?',
            variables: [drift.Variable(anchorId)],
          )
          .getSingleOrNull();
      final payload = row == null
          ? null
          : jsonDecode(row.data['payload'] as String) as Map;
      final passage = ReaderTextAnchor.decode(payload?['textRange']);
      if (passage != null && widget.onJumpToTextAnchor != null) {
        if (mounted) Navigator.pop(context);
        widget.onJumpToTextAnchor!(passage);
        return;
      }
      final locator = row == null
          ? null
          : ReaderLocator.decode(
              (jsonDecode(row.data['payload'] as String) as Map)['locator']
                  as String?,
            );
      if (locator != null && widget.onJumpToAnchor != null) {
        if (mounted) Navigator.pop(context);
        widget.onJumpToAnchor!(locator);
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
    if (position != null) widget.onJumpToPosition?.call(position);
    if (page != null) widget.onJumpToPage?.call(page);
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showStudyAdaptiveModal<bool>(
      context: context,
      builder: (_) => const StudyConfirmDialog(
        title: 'Delete this note?',
        message: 'This note will be removed from the lesson and Study space.',
        confirmLabel: 'Delete note',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
    );
    if (confirmed == true) await widget.database.deleteNoteSoft(note.id);
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    final confirmed = await showStudyAdaptiveModal<bool>(
      context: context,
      builder: (_) => const StudyConfirmDialog(
        title: 'Delete this bookmark?',
        message: 'This saved location will be removed from the lesson.',
        confirmLabel: 'Delete bookmark',
        icon: Icons.bookmark_remove_outlined,
        destructive: true,
      ),
    );
    if (confirmed == true) {
      await widget.database.deleteBookmarkSoft(bookmark.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final panel = SizedBox(
      height:
          MediaQuery.sizeOf(context).height *
          (AppBreakpoints.isCompact(context) ? .82 : .76),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.sm,
              AppSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            cleanDisplayTitle(
                              widget.item.userTitle ?? widget.item.title,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _tab == 0 ? 'Add note' : 'Add bookmark',
                      onPressed: _tab == 0 ? _addNote : _addBookmark,
                      icon: const Icon(Icons.add_rounded),
                    ),
                    IconButton(
                      tooltip: 'Close study tools',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                StudyStatusBadge(
                  label: _location(
                    widget.currentPositionSeconds,
                    widget.currentPage,
                  ),
                  icon: widget.currentPage != null
                      ? Icons.menu_book_rounded
                      : Icons.schedule_rounded,
                  tone: StudyStatusTone.primary,
                ),
              ],
            ),
          ),
          if (widget.textAnchor != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.textAnchor!.quote,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Attach new notes and bookmarks to this passage',
                    ),
                    value: _useSelection,
                    onChanged: (value) => setState(() => _useSelection = value),
                  ),
                ],
              ),
            ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.notes),
                label: Text('Notes'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.bookmark_outline),
                label: Text('Bookmarks'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => setState(() => _tab = value.first),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: TextField(
              controller: _search,
              maxLength: 256,
              decoration: InputDecoration(
                labelText: 'Search this title’s Study entries',
                suffixIcon: IconButton(
                  tooltip: 'Search entries',
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    _query = _search.text.trim();
                    _firstPages();
                  },
                ),
              ),
              onSubmitted: (value) {
                _query = value.trim();
                _firstPages();
              },
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Expanded(child: _tab == 0 ? _notes() : _bookmarks()),
        ],
      ),
    );
    if (AppBreakpoints.isCompact(context)) {
      return SafeArea(top: false, child: panel);
    }
    return Dialog(child: SizedBox(width: 640, child: panel));
  }

  Widget _notes() {
    return StreamBuilder<StudyPageResult>(
      stream: _pages[0],
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: ContentState(
              icon: Icons.error_outline_rounded,
              title: 'Notes could not load',
              message: 'Your notes are temporarily unavailable.',
              tone: ContentStateTone.error,
              compact: true,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: ContentLoadingState(label: 'Loading notes'),
          );
        }
        final page =
            snapshot.data ?? const StudyPageResult(entries: [], anchors: {});
        final notes = page.entries.map(Note.fromJson).toList();
        return Column(
          children: [
            Expanded(
              child: StudyAnimatedList<Note>(
                key: const ValueKey('lesson-notes'),
                items: notes,
                itemId: (note) => note.id,
                emptyState: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: ContentState(
                    icon: Icons.note_add_outlined,
                    title: 'No notes for this title',
                    message:
                        'Capture a thought at the current ${widget.currentPage != null ? 'page' : 'moment'}.',
                    action: FilledButton.icon(
                      onPressed: _addNote,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add note'),
                    ),
                    compact: true,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, note) {
                  return StudySurface(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.notes_rounded),
                      title: Text(
                        note.content,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: StudyStatusBadge(
                          label: _location(
                            note.positionSeconds,
                            note.pageNumber,
                          ),
                          icon: note.pageNumber != null
                              ? Icons.menu_book_rounded
                              : Icons.schedule_rounded,
                          tone: StudyStatusTone.info,
                        ),
                      ),
                      onTap:
                          note.positionSeconds != null ||
                              note.pageNumber != null
                          ? () => _jump(
                              position: note.positionSeconds,
                              page: note.pageNumber,
                              anchorId: 'note:${note.id}',
                            )
                          : null,
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Note actions',
                        onSelected: (value) {
                          if (value == 'edit') _editNote(note);
                          if (value == 'delete') _deleteNote(note);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _pager(0, page),
          ],
        );
      },
    );
  }

  Widget _bookmarks() {
    return StreamBuilder<StudyPageResult>(
      stream: _pages[1],
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: ContentState(
              icon: Icons.error_outline_rounded,
              title: 'Bookmarks could not load',
              message:
                  'Your saved lesson locations are temporarily unavailable.',
              tone: ContentStateTone.error,
              compact: true,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: ContentLoadingState(label: 'Loading bookmarks'),
          );
        }
        final page =
            snapshot.data ?? const StudyPageResult(entries: [], anchors: {});
        final bookmarks = page.entries.map(Bookmark.fromJson).toList();
        return Column(
          children: [
            Expanded(
              child: StudyAnimatedList<Bookmark>(
                key: const ValueKey('lesson-bookmarks'),
                items: bookmarks,
                itemId: (bookmark) => bookmark.id,
                emptyState: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: ContentState(
                    icon: Icons.bookmark_add_outlined,
                    title: 'No bookmarks for this title',
                    message:
                        'Save this ${widget.currentPage != null ? 'page' : 'moment'} so it is easy to find again.',
                    action: FilledButton.icon(
                      onPressed: _addBookmark,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add bookmark'),
                    ),
                    compact: true,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, bookmark) {
                  return StudySurface(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.bookmark_rounded),
                      title: Text(bookmark.title),
                      subtitle: Text(
                        [
                          _location(
                            bookmark.positionSeconds,
                            bookmark.pageNumber,
                          ),
                          if ((bookmark.description ?? '').isNotEmpty)
                            bookmark.description!,
                        ].join(' · '),
                      ),
                      onTap: () => _jump(
                        position: bookmark.positionSeconds,
                        page: bookmark.pageNumber,
                        anchorId: 'bookmark:${bookmark.id}',
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Bookmark actions',
                        onSelected: (value) {
                          if (value == 'edit') _editBookmark(bookmark);
                          if (value == 'delete') _deleteBookmark(bookmark);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _pager(1, page),
          ],
        );
      },
    );
  }

  String _location(double? position, int? page) {
    if (page != null) return 'Page $page';
    if (position != null) return _formatDuration(position);
    return 'General lesson note';
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) return '${duration.inHours}:$minutes:$secs';
    return '$minutes:$secs';
  }
}
