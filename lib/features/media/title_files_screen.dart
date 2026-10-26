import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/catalog_playback.dart';
import '../../domain/catalog/catalog_hints.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../shared/widgets/study_ui.dart';

/// One file remains the owner of its progress, even when it belongs to a title.
class TitleFilesScreen extends ConsumerStatefulWidget {
  const TitleFilesScreen({super.key, required this.item, this.suggestedExtra});
  final Item item;
  final Item? suggestedExtra;
  @override
  ConsumerState<TitleFilesScreen> createState() => _TitleFilesState();
}

class _TitleFilesState extends ConsumerState<TitleFilesScreen> {
  final _edition = TextEditingController();
  final _representation = TextEditingController();
  TitleFiles? _saved;
  final _parts = <CatalogPart>[];
  final _extras = <CatalogExtra>[];
  String? _error;
  String? _displayTitle;
  bool _busy = true, _dirty = false;
  double _position = 0;
  CatalogPlayback get _catalog =>
      CatalogPlayback(ref.read(appDatabaseProvider));
  bool get _playable => {'video', 'audio'}.contains(widget.item.itemType);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _edition.dispose();
    _representation.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      final files = await _catalog.files(widget.item);
      final metadata = await MediaCatalogRepository(
        ref.read(appDatabaseProvider),
      ).metadata(widget.item);
      if (!mounted) return;
      setState(() {
        _saved = files;
        _displayTitle =
            metadata['title'] as String? ??
            widget.item.userTitle ??
            widget.item.title;
        _edition.text = files.edition;
        _representation.text = files.representation;
        _parts
          ..clear()
          ..addAll(files.parts);
        _extras
          ..clear()
          ..addAll(files.extras);
        _error = null;
        _dirty = false;
        final suggested = widget.suggestedExtra;
        if (suggested != null &&
            suggested.id != widget.item.id &&
            !_extras.any((e) => e.item.id == suggested.id) &&
            !_parts.any((p) => p.item.id == suggested.id)) {
          _extras.add(
            CatalogExtra(
              item: suggested,
              kind: CatalogHints.extraKind(suggested.relativePath) ?? 'extra',
            ),
          );
          _dirty = true;
        }
        _position = 0;
      });
    } on Object {
      if (mounted) setState(() => _error = 'Files could not load. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final saved = _saved;
    if (saved == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _catalog.saveFiles(
        widget.item,
        expected: saved.token,
        edition: _edition.text,
        representation: _representation.text,
        parts: _parts.map((p) => p.item).toList(),
        extras: _extras,
      );
      await _reload();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Title files saved')));
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted)
        setState(
          () => _error =
              'The files could not be saved. Your edits are still here.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add({required bool part}) async {
    final picked = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LibraryFilePicker(
        libraryId: widget.item.libraryId,
        itemType: part ? widget.item.itemType : null,
        excluded: part
            ? _parts.map((p) => p.item.id).toSet()
            : {
                widget.item.id,
                ..._parts.map((p) => p.item.id),
                ..._extras.map((e) => e.item.id),
              },
        needsDuration: part,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (part) {
        _parts.add(
          CatalogPart(
            item: picked,
            duration: picked.durationSeconds!,
            offset: 0,
          ),
        );
        _extras.removeWhere((extra) => extra.item.id == picked.id);
      } else {
        _extras.add(
          CatalogExtra(
            item: picked,
            kind: CatalogHints.extraKind(picked.relativePath) ?? 'extra',
          ),
        );
      }
      _dirty = true;
    });
  }

  Future<void> _play({bool resume = false}) async {
    try {
      final target = resume
          ? await _catalog.resumePart(widget.item.id)
          : await _catalog.locatePart(widget.item.id, _position);
      if (mounted)
        context.push(
          CatalogPlayback.partRoute(
            widget.item.id,
            target.itemId,
            position: target.position,
          ),
        );
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A part is unavailable or its timing changed. Reload the saved files.',
            ),
          ),
        );
    }
  }

  void _move(int index, int direction) => setState(() {
    final part = _parts.removeAt(index);
    _parts.insert(index + direction, part);
    _dirty = true;
  });

  @override
  Widget build(BuildContext context) {
    final total = _parts.fold<double>(0, (sum, part) => sum + part.duration);
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard file changes?'),
            content: const Text('Your saved title files will be kept.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard changes'),
              ),
            ],
          ),
        );
        if (discard == true && mounted) {
          setState(() => _dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: 'Editions, parts and extras',
          showBack: true,
          actions: [
            TextButton(
              onPressed: _busy || !_dirty ? null : _save,
              child: const Text('Save changes'),
            ),
          ],
        ),
        body: StudyPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudyPageHeader(
                title: _displayTitle ?? 'Title files',
                description:
                    'Manage versions, parts and extras. Each file keeps its own history.',
              ),
              const SizedBox(height: 24),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _busy ? null : _reload,
                  child: const Text('Reload saved files'),
                ),
              ],
              if (_saved != null) ...[
                Text(
                  'Edition and version',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _edition,
                  enabled: !_busy,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Edition',
                    hintText: 'Original, theatrical, director’s cut…',
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                TextField(
                  controller: _representation,
                  enabled: !_busy,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'File version',
                    hintText: '1080p, original audio, restored scan…',
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                SelectableText(widget.item.filename),
                const SizedBox(height: 24),
                if (_playable) ...[
                  _heading(
                    'Multipart playback',
                    'Add the full ordered list of files. Durations must be known before a title position can be mapped.',
                    () => _add(part: true),
                    'Add part',
                  ),
                  if (_parts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('This title plays as one file.'),
                    ),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _parts.length,
                    onReorder: (oldIndex, newIndex) {
                      if (_busy) return;
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        _parts.insert(newIndex, _parts.removeAt(oldIndex));
                        _dirty = true;
                      });
                    },
                    itemBuilder: (context, index) {
                      final part = _parts[index];
                      return ListTile(
                        key: ValueKey(part.item.id),
                        leading: ReorderableDragStartListener(
                          enabled: !_busy,
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(
                          '${index + 1}. ${part.item.userTitle ?? part.item.title}',
                        ),
                        subtitle: Text(
                          '${part.item.filename} · ${_time(part.duration)}${part.item.unavailable ? ' · unavailable' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Move part up',
                              onPressed: _busy || index == 0
                                  ? null
                                  : () => _move(index, -1),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'Move part down',
                              onPressed: _busy || index == _parts.length - 1
                                  ? null
                                  : () => _move(index, 1),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              tooltip: 'Remove part',
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _parts.removeAt(index);
                                      _dirty = true;
                                    }),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_parts.isNotEmpty) ...[
                    Text('Total duration · ${_time(total)}'),
                    Slider(
                      value: _position.clamp(0, total),
                      max: total,
                      label: _time(_position),
                      onChanged: _dirty || _busy
                          ? null
                          : (value) => setState(() => _position = value),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _dirty || _busy
                              ? null
                              : () => _play(resume: true),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume title'),
                        ),
                        OutlinedButton(
                          onPressed: _dirty || _busy ? null : _play,
                          child: Text('Play from ${_time(_position)}'),
                        ),
                      ],
                    ),
                    if (_dirty)
                      const Text('Save changes to play the updated sequence.'),
                  ],
                  const SizedBox(height: 24),
                ],
                _heading(
                  'Extras',
                  'Bonus files open only when you choose them.',
                  () => _add(part: false),
                  'Add extra',
                ),
                if (_extras.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No extras attached.'),
                  ),
                for (var index = 0; index < _extras.length; index++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(MediaVisuals.icon(_extras[index].item)),
                    title: Text(
                      _extras[index].item.userTitle ??
                          _extras[index].item.title,
                    ),
                    subtitle: DropdownButton<String>(
                      value: _extras[index].kind,
                      items: CatalogPlayback.extraKinds.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (kind) => setState(() {
                              _extras[index] = CatalogExtra(
                                item: _extras[index].item,
                                kind: kind!,
                              );
                              _dirty = true;
                            }),
                    ),
                    trailing: IconButton(
                      tooltip: 'Detach extra',
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _extras.removeAt(index);
                              _dirty = true;
                            }),
                      icon: const Icon(Icons.link_off),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(
    String title,
    String description,
    VoidCallback onAdd,
    String action,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      Text(description),
      TextButton.icon(
        onPressed: _busy ? null : onAdd,
        icon: const Icon(Icons.add),
        label: Text(action),
      ),
    ],
  );
}

String _time(double seconds) {
  final value = seconds.floor();
  return '${value ~/ 3600}:${((value ~/ 60) % 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

/// Shared bounded picker for manual associations; no automatic parent selection.
Future<Item?> chooseLibraryParent(
  BuildContext context, {
  required String libraryId,
  required String extraId,
}) => showModalBottomSheet<Item>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _LibraryFilePicker(
    libraryId: libraryId,
    excluded: {extraId},
    needsDuration: false,
    itemType: 'video',
    title: 'Choose the parent title',
  ),
);

class _LibraryFilePicker extends ConsumerStatefulWidget {
  const _LibraryFilePicker({
    required this.libraryId,
    required this.excluded,
    required this.needsDuration,
    this.itemType,
    this.title,
  });
  final String libraryId;
  final Set<String> excluded;
  final bool needsDuration;
  final String? itemType, title;
  @override
  ConsumerState<_LibraryFilePicker> createState() => _LibraryFilePickerState();
}

class _LibraryFilePickerState extends ConsumerState<_LibraryFilePicker> {
  final _search = TextEditingController();
  final _history = <String?>[];
  String? _after;
  late Future<List<Item>> _rows = _load();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Item>> _load() async {
    final db = ref.read(appDatabaseProvider);
    final rows = await db
        .customSelect(
          '''SELECT i.* FROM items i WHERE i.library_id=? AND i.unavailable=0
      ${widget.title == null ? '' : "AND NOT EXISTS(SELECT 1 FROM media_extras e WHERE e.item_id=i.id) AND NOT EXISTS(SELECT 1 FROM catalog_facets f WHERE f.item_id=i.id AND f.field='extra' AND f.value='true')"}
      AND (? IS NULL OR i.item_type=?) AND (i.title LIKE ? ESCAPE '\\' OR i.filename LIKE ? ESCAPE '\\')
      AND (? IS NULL OR i.id>?) ORDER BY i.id LIMIT 41''',
          variables: [
            drift.Variable(widget.libraryId),
            drift.Variable<String>(widget.itemType),
            drift.Variable<String>(widget.itemType),
            drift.Variable(
              '%${_search.text.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
            ),
            drift.Variable(
              '%${_search.text.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
            ),
            drift.Variable<String>(_after),
            drift.Variable<String>(_after),
          ],
        )
        .get();
    return rows.map((row) => db.items.map(row.data)).toList();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.title ??
                  (widget.needsDuration ? 'Choose a part' : 'Choose an extra'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Search this library',
                suffixIcon: IconButton(
                  tooltip: 'Search files',
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() {
                    _after = null;
                    _history.clear();
                    _rows = _load();
                  }),
                ),
              ),
              onSubmitted: (_) => setState(() {
                _after = null;
                _history.clear();
                _rows = _load();
              }),
            ),
            Expanded(
              child: FutureBuilder<List<Item>>(
                future: _rows,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(() => _rows = _load()),
                        child: const Text('Could not load files. Retry'),
                      ),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final rows = snapshot.data!.take(40).toList();
                  return Column(
                    children: [
                      Expanded(
                        child: rows.isEmpty
                            ? const Center(child: Text('No matching files.'))
                            : ListView.builder(
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final item = rows[index];
                                  final selected = widget.excluded.contains(
                                    item.id,
                                  );
                                  final timed =
                                      item.durationSeconds != null &&
                                      item.durationSeconds!.isFinite &&
                                      item.durationSeconds! > 0;
                                  return ListTile(
                                    enabled:
                                        !selected &&
                                        (!widget.needsDuration || timed),
                                    leading: Icon(MediaVisuals.icon(item)),
                                    title: Text(item.userTitle ?? item.title),
                                    subtitle: Text(
                                      '${item.filename}${selected
                                          ? ' · already selected'
                                          : widget.needsDuration && !timed
                                          ? ' · duration not available'
                                          : ''}',
                                    ),
                                    onTap: () => Navigator.pop(context, item),
                                  );
                                },
                              ),
                      ),
                      if (_history.isNotEmpty || snapshot.data!.length > 40)
                        Row(
                          children: [
                            TextButton(
                              onPressed: _history.isEmpty
                                  ? null
                                  : () => setState(() {
                                      _after = _history.removeLast();
                                      _rows = _load();
                                    }),
                              child: const Text('Previous'),
                            ),
                            TextButton(
                              onPressed: snapshot.data!.length <= 40
                                  ? null
                                  : () => setState(() {
                                      _history.add(_after);
                                      _after = rows.last.id;
                                      _rows = _load();
                                    }),
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
