import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import 'content_state.dart';
import 'study_animated_list.dart';
import 'study_ui.dart';

Future<void> showLessonToolsSheet({
  required BuildContext context,
  required AppDatabase database,
  required Item item,
  double? currentPositionSeconds,
  int? currentPage,
  ValueChanged<double>? onJumpToPosition,
  ValueChanged<int>? onJumpToPage,
}) {
  return showStudyAdaptiveModal<void>(
    context: context,
    builder: (_) => LessonToolsSheet(
      database: database,
      item: item,
      currentPositionSeconds: currentPositionSeconds,
      currentPage: currentPage,
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
    this.currentPositionSeconds,
    this.currentPage,
    this.onJumpToPosition,
    this.onJumpToPage,
  });

  final AppDatabase database;
  final Item item;
  final double? currentPositionSeconds;
  final int? currentPage;
  final ValueChanged<double>? onJumpToPosition;
  final ValueChanged<int>? onJumpToPage;

  @override
  State<LessonToolsSheet> createState() => _LessonToolsSheetState();
}

class _LessonToolsSheetState extends State<LessonToolsSheet> {
  int _tab = 0;

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
    final content = await _askForText(title: 'Add note', label: 'Note');
    if (content == null || content.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await widget.database.upsertNote(
      NotesCompanion.insert(
        id: const Uuid().v4(),
        libraryId: widget.item.libraryId,
        itemId: drift.Value(widget.item.id),
        content: content,
        positionSeconds: drift.Value(widget.currentPositionSeconds),
        pageNumber: drift.Value(widget.currentPage),
        createdAt: now,
        updatedAt: now,
        deviceId: await widget.database.getDeviceId(),
      ),
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
    await widget.database.upsertBookmark(
      BookmarksCompanion.insert(
        id: const Uuid().v4(),
        libraryId: widget.item.libraryId,
        itemId: widget.item.id,
        title: value.title,
        description: drift.Value(value.description),
        positionSeconds: drift.Value(widget.currentPositionSeconds),
        pageNumber: drift.Value(widget.currentPage),
        createdAt: now,
        updatedAt: now,
        deviceId: await widget.database.getDeviceId(),
      ),
    );
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

  void _jump({double? position, int? page}) {
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
                            'Study tools',
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
    return StreamBuilder<List<Note>>(
      stream: widget.database.watchNotes(itemId: widget.item.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: ContentState(
              icon: Icons.error_outline_rounded,
              title: 'Notes could not load',
              message: 'Your lesson notes are temporarily unavailable.',
              tone: ContentStateTone.error,
              compact: true,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: ContentLoadingState(label: 'Loading lesson notes'),
          );
        }
        final notes = snapshot.data ?? const [];
        return StudyAnimatedList<Note>(
          key: const ValueKey('lesson-notes'),
          items: notes,
          itemId: (note) => note.id,
          emptyState: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: ContentState(
              icon: Icons.note_add_outlined,
              title: 'No notes in this lesson',
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
                title: Text(note.content),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: StudyStatusBadge(
                    label: _location(note.positionSeconds, note.pageNumber),
                    icon: note.pageNumber != null
                        ? Icons.menu_book_rounded
                        : Icons.schedule_rounded,
                    tone: StudyStatusTone.info,
                  ),
                ),
                onTap: note.positionSeconds != null || note.pageNumber != null
                    ? () => _jump(
                        position: note.positionSeconds,
                        page: note.pageNumber,
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
        );
      },
    );
  }

  Widget _bookmarks() {
    return StreamBuilder<List<Bookmark>>(
      stream: widget.database.watchBookmarks(itemId: widget.item.id),
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
            child: ContentLoadingState(label: 'Loading lesson bookmarks'),
          );
        }
        final bookmarks = snapshot.data ?? const [];
        return StudyAnimatedList<Bookmark>(
          key: const ValueKey('lesson-bookmarks'),
          items: bookmarks,
          itemId: (bookmark) => bookmark.id,
          emptyState: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: ContentState(
              icon: Icons.bookmark_add_outlined,
              title: 'No bookmarks in this lesson',
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
                    _location(bookmark.positionSeconds, bookmark.pageNumber),
                    if ((bookmark.description ?? '').isNotEmpty)
                      bookmark.description!,
                  ].join(' · '),
                ),
                onTap: () => _jump(
                  position: bookmark.positionSeconds,
                  page: bookmark.pageNumber,
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
