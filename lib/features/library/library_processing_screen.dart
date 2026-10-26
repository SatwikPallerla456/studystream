import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/app_providers.dart';
import '../media/title_files_screen.dart';
import '../../domain/catalog/library_processing.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/study_ui.dart';
import 'automatic_identification_controls.dart';
import '../media/catalog_editor_screen.dart';

class LibraryProcessingButton extends ConsumerWidget {
  const LibraryProcessingButton({super.key, required this.libraryId});
  final String libraryId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    icon: const Icon(Icons.auto_awesome_motion_outlined),
    label: const Text('Processing'),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LibraryProcessingScreen(libraryId: libraryId),
      ),
    ),
  );
}

class LibraryProcessingScreen extends ConsumerStatefulWidget {
  const LibraryProcessingScreen({super.key, required this.libraryId});
  final String libraryId;
  @override
  ConsumerState<LibraryProcessingScreen> createState() => _ProcessingState();
}

class _ProcessingState extends ConsumerState<LibraryProcessingScreen> {
  String? _after;
  final _history = <String?>[];
  bool _busy = false;
  String? _message;
  LibraryProcessingService get _service => ref.read(libraryProcessingProvider);
  LibraryProcessingStore get _store => _service.store;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted)
        setState(() => _message = 'This action could not finish. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(Map<String, dynamic> row) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final candidate = await db.getItemById(row['item_id'] as String);
      if (candidate == null || !mounted) return;
      final extra = row['reason'] != 'multipartCandidate';
      final targetId = row['target_id'] as String?;
      final parent = targetId == null && extra
          ? await chooseLibraryParent(
              context,
              libraryId: widget.libraryId,
              extraId: candidate.id,
            )
          : await db.getItemById(targetId ?? candidate.id);
      if (parent == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TitleFilesScreen(
            item: parent,
            suggestedExtra: extra ? candidate : null,
          ),
        ),
      );
      _store.notify();
    } catch (_) {
      if (mounted)
        setState(
          () => _message =
              'This candidate could not open. Refresh the library and try again.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(appDatabaseProvider);
    return Scaffold(
      appBar: AppTopBar(title: 'Library processing', showBack: true),
      body: StudyPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready behind the scenes',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'New and changed files are organized, analyzed and identified automatically while Tangerine is open. Playback and reading take priority. Your files, matches, notes and progress stay in place.',
            ),
            AutomaticIdentificationControls(libraryId: widget.libraryId),
            const SizedBox(height: 20),
            StreamBuilder<List<drift.QueryRow>>(
              stream: _store.watchSummary(widget.libraryId),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Text(
                    'Processing summary could not load. Reopen this screen to retry.',
                  );
                final rows = snapshot.data ?? [];
                int count(String state) => rows
                    .where((r) => r.data['state'] == state)
                    .fold(0, (n, r) => n + (r.data['total'] as int));
                return Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final state in [
                      'queued',
                      'running',
                      'complete',
                      'failed',
                      'deferred',
                      'unsupported',
                      'review',
                    ])
                      Chip(label: Text('${_state(state)} · ${count(state)}')),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder(
              stream: db
                  .customSelect(
                    'SELECT value FROM app_settings WHERE key=?',
                    variables: [
                      drift.Variable('processing.pause:${widget.libraryId}'),
                    ],
                    readsFrom: {db.appSettings},
                  )
                  .watch(),
              builder: (context, snapshot) {
                final paused =
                    snapshot.data?.firstOrNull?.data['value'] == 'true';
                return Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _service.pause(widget.libraryId, !paused),
                            ),
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                      label: Text(
                        paused ? 'Resume processing' : 'Pause processing',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _store.retryFailures(widget.libraryId),
                            ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry failed / unavailable'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _store.enqueueLibrary(
                                widget.libraryId,
                                force: true,
                              ),
                            ),
                      child: const Text('Reprocess this library'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Pause stops new work and discards an in-flight result after its resources are released. Offline sources wait for reconnection. Failed files receive up to three automatic attempts; unsupported files wait for an explicit retry.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) Text(_message!),
            const SizedBox(height: 24),
            Text(
              'Organization review',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Split files and extras are candidates, not automatic merges. Review their editions, timings and relationships in Files & versions.',
            ),
            StreamBuilder(
              stream: db
                  .customSelect(
                    '''SELECT s.*,i.title FROM processing_suggestions s JOIN items i ON i.id=s.item_id
        WHERE s.library_id=? AND s.dismissed=0
        AND NOT EXISTS(SELECT 1 FROM media_extras e WHERE e.item_id=s.item_id)
        AND NOT EXISTS(SELECT 1 FROM media_parts p WHERE p.item_id=s.item_id OR p.representation_id=s.item_id)
        ORDER BY s.item_id LIMIT 51''',
                    variables: [drift.Variable(widget.libraryId)],
                    readsFrom: {db.items, db.appSettings},
                  )
                  .watch(),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? [];
                if (rows.isEmpty)
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No organization candidates waiting.'),
                  );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final row in rows.take(50))
                      ListTile(
                        title: Text(row.data['title'] as String),
                        subtitle: Text(switch (row.data['reason']) {
                          'multipartCandidate' =>
                            'Possible split title · confirm ordered parts and timing',
                          'extraCandidate' =>
                            'Possible associated extra · confirm its parent',
                          _ =>
                            'Extra with an ambiguous parent · choose its title',
                        }),
                        onTap: () => _review(row.data),
                        trailing: IconButton(
                          tooltip: 'Dismiss this suggestion',
                          icon: const Icon(Icons.close),
                          onPressed: () => _run(() async {
                            await db.customStatement(
                              'UPDATE processing_suggestions SET dismissed=1 WHERE item_id=?',
                              [row.data['item_id']],
                            );
                            _store.notify();
                          }),
                        ),
                      ),
                    if (rows.length > 50)
                      const Text(
                        'Showing 50 candidates. Dismiss or organize these to reveal more.',
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('File jobs', style: Theme.of(context).textTheme.titleLarge),
            StreamBuilder<List<drift.QueryRow>>(
              stream: _store.watchJobs(widget.libraryId, after: _after),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Text(
                    'Processing status could not load. Reopen this screen to retry.',
                  );
                final rows = snapshot.data ?? [];
                return Column(
                  children: [
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Files will appear here as the background queue discovers them.',
                        ),
                      ),
                    for (final row in rows.take(50))
                      ListTile(
                        title: Text(
                          '${row.data['user_title'] ?? row.data['title']}',
                        ),
                        subtitle: Text(
                          '${row.data['kind'] == 'identify'
                              ? 'TheTVDB identification'
                              : row.data['kind'] == 'analyze'
                              ? 'Technical analysis'
                              : 'Local organization'} · ${_state(row.data['state'] as String)}${row.data['unavailable'] == 1 ? ' · Source offline' : ''}${row.data['error_code'] == null ? '' : ' · ${_error(row.data['error_code'] as String)}'}',
                        ),
                        trailing: row.data['kind'] == 'identify'
                            ? const Icon(Icons.manage_search)
                            : null,
                        onTap: () async {
                          if (row.data['kind'] == 'identify') {
                            final item = await db.getItemById(
                              row.data['item_id'] as String,
                            );
                            if (item != null && context.mounted)
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      CatalogEditorScreen(item: item),
                                ),
                              );
                          } else if (context.mounted) {
                            context.push(
                              '/details/${Uri.encodeComponent(row.data['item_id'] as String)}',
                            );
                          }
                        },
                      ),
                    if (_history.isNotEmpty || rows.length > 50)
                      Wrap(
                        spacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: _history.isEmpty
                                ? null
                                : () => setState(
                                    () => _after = _history.removeLast(),
                                  ),
                            child: const Text('Previous page'),
                          ),
                          OutlinedButton(
                            onPressed: rows.length <= 50
                                ? null
                                : () => setState(() {
                                    _history.add(_after);
                                    final last = rows[49];
                                    _after =
                                        '${last.data['item_id']}:${last.data['kind']}';
                                  }),
                            child: const Text('Next page'),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _state(String state) => switch (state) {
    'queued' => 'Waiting',
    'running' => 'Processing',
    'complete' => 'Ready',
    'failed' => 'Needs retry',
    'deferred' => 'Waiting for source',
    'unsupported' => 'Unsupported',
    'review' => 'Needs review',
    _ => state,
  };
  static String _error(String error) => switch (error) {
    'sourceUnavailable' => 'Reconnect or rescan the source',
    'parseFailed' => 'File format could not be read',
    'noMatch' => 'No match found; try manual search',
    'ambiguous' => 'No unique title/year match; choose manually',
    'identityNeeded' => 'Add a year or choose a manual match',
    'episodeNeeded' => 'Check season and episode, then match manually',
    'decisionKept' => 'Existing match or clear decision kept',
    'categoryUnsupported' => 'Automatic matching supports movies and TV',
    'providerUnavailable' => 'Provider unavailable; retry or use manual search',
    _ => 'Processing could not finish',
  };
}
