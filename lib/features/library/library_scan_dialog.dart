import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/app_providers.dart';
import '../../data/indexer/library_indexer.dart';
import '../../domain/catalog/media_catalog_repository.dart';

Future<String?> showLibraryScan(
  BuildContext context, {
  String? libraryId,
  String? root,
  String? name,
  LibraryKind? kind,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _LibraryScan(libraryId: libraryId, root: root, name: name, kind: kind),
);

class _LibraryScan extends ConsumerStatefulWidget {
  const _LibraryScan({this.libraryId, this.root, this.name, this.kind});
  final String? libraryId, root, name;
  final LibraryKind? kind;
  @override
  ConsumerState<_LibraryScan> createState() => _LibraryScanState();
}

class _LibraryScanState extends ConsumerState<_LibraryScan> {
  final _token = ScanCancellationToken();
  ScanProgress? _progress;
  bool _running = true;
  String? _id, _message;
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final db = ref.read(appDatabaseProvider),
        indexer = ref.read(libraryIndexerProvider);
    final catalog = MediaCatalogRepository(db);
    try {
      void progress(ScanProgress value) {
        if (mounted) setState(() => _progress = value);
      }

      if (widget.libraryId == null) {
        final result = await indexer.scanRootFolder(
          rootFolderPath: widget.root!,
          title: widget.name!,
          cancellationToken: _token,
          onProgress: progress,
        );
        _id = result.libraryId;
        await catalog.setLibraryKind(_id!, widget.kind!);
        _message =
            '${result.importedItems} files indexed${result.errors.isEmpty ? '' : ' · ${result.errors.length} need attention'}';
      } else {
        final library = await db.getLibraryById(widget.libraryId!);
        if (library == null)
          throw const FormatException('This library is unavailable.');
        final sources = await catalog.sources(library.id);
        if (sources.isEmpty)
          throw const FormatException(
            'Add a source folder in Library settings first.',
          );
        var files = 0, issues = 0;
        for (final source in sources) {
          _token.throwIfCancelled();
          try {
            final result = await indexer.scanRootFolder(
              rootFolderPath: source.root,
              title: library.title,
              existingLibraryId: library.id,
              source: source,
              cancellationToken: _token,
              onProgress: progress,
            );
            files += result.importedItems;
            issues += result.errors.length;
          } on ScanCancelledException {
            rethrow;
          } catch (_) {
            issues++;
          }
        }
        _id = library.id;
        _message =
            '$files files indexed${issues == 0 ? '' : ' · $issues source or file issues'}';
      }
    } on ScanCancelledException {
      _message = 'Scan cancelled. Existing files and saved progress were kept.';
    } catch (error) {
      _message = error is FormatException
          ? error.message.toString()
          : 'The scan could not finish. Check source access and try again.';
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    _token.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_running,
    child: AlertDialog(
      title: Text(_running ? 'Scanning library' : 'Library scan'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_running) ...[
              LinearProgressIndicator(value: _progress?.fraction),
              const SizedBox(height: 16),
              Text(_progress?.phase ?? 'Preparing sources…'),
              Text(
                '${_progress?.processedFiles ?? 0} of ${_progress?.discoveredFiles ?? 0} files',
              ),
            ] else
              Text(_message ?? 'Scan finished.'),
          ],
        ),
      ),
      actions: [
        if (_running)
          TextButton(
            onPressed: () {
              _token.cancel();
              setState(() => _message = 'Cancelling…');
            },
            child: Text(_token.isCancelled ? 'Cancelling…' : 'Cancel scan'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(context, _id),
            child: const Text('Done'),
          ),
      ],
    ),
  );
}
