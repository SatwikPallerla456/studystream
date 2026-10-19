import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as p;

import '../../core/constants/supported_extensions.dart';
import '../../core/utils/id_utils.dart';
import '../../core/utils/sort_utils.dart';
import '../db/app_database.dart';
import 'library_source_store.dart';
import '../../domain/catalog/catalog_identity_store.dart';
import '../../domain/catalog/media_catalog_repository.dart';

typedef ScanProgressCallback = void Function(ScanProgress progress);

class ScanProgress {
  const ScanProgress({
    required this.phase,
    required this.discoveredFiles,
    required this.processedFiles,
    this.currentPath,
  });

  final String phase;
  final int discoveredFiles;
  final int processedFiles;
  final String? currentPath;

  double? get fraction =>
      discoveredFiles == 0 ? null : processedFiles / discoveredFiles;
}

class ScanResult {
  const ScanResult({
    required this.libraryId,
    required this.importedItems,
    required this.missingItems,
    required this.skippedFiles,
    required this.errors,
    this.outcome = 'complete',
  });

  final String outcome;
  final String libraryId;
  final int importedItems;
  final int missingItems;
  final int skippedFiles;
  final List<String> errors;
}

class ScanCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const ScanCancelledException();
  }
}

class ScanCancelledException implements Exception {
  const ScanCancelledException();

  @override
  String toString() => 'Library scan cancelled';
}

class LibraryIndexer {
  LibraryIndexer(this.db);

  final AppDatabase db;
  Future<void> _queue = Future.value();

  Future<String> importRootFolder({
    required String rootFolderPath,
    required String title,
    ScanProgressCallback? onProgress,
    ScanCancellationToken? cancellationToken,
  }) async {
    final result = await scanRootFolder(
      rootFolderPath: rootFolderPath,
      title: title,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
    return result.libraryId;
  }

  Future<ScanResult> scanRootFolder({
    required String rootFolderPath,
    required String title,
    String? existingLibraryId,
    LibrarySource? source,
    ScanProgressCallback? onProgress,
    ScanCancellationToken? cancellationToken,
  }) {
    final scan = _queue.then((_) async {
      if(source != null && (existingLibraryId != source.libraryId || !p.equals(p.normalize(rootFolderPath),p.normalize(source.root)))) {
        throw const FormatException('Scan source ownership does not match');
      }
      final libraryId=existingLibraryId ?? stableId(p.canonicalize(p.normalize(rootFolderPath)));
      final sourceId=source?.id ?? 'legacy:$libraryId';
      final store=LibrarySourceStore(db);
      final session=await store.begin(sourceId,rootFolderPath);
      try {
        final result=await _scanRootFolder(rootFolderPath:rootFolderPath,title:title,
          existingLibraryId:existingLibraryId,source:source,onProgress:onProgress,
          cancellationToken:cancellationToken,sessionId:session);
        await store.finish(session,result.outcome,discovered:result.importedItems,
          processed:result.importedItems,errors:jsonEncode(result.errors));
        return result;
      } on ScanCancelledException {
        await store.finish(session,'cancelled');
        rethrow;
      } on Object catch(error) {
        await store.finish(session,'failed',errors:jsonEncode([error.toString()]));
        rethrow;
      }
    });
    _queue = scan.then<void>((_) {}, onError: (Object _) {});
    return scan;
  }

  Future<ScanResult> _scanRootFolder({
    required String rootFolderPath,
    required String title,
    required String sessionId,
    String? existingLibraryId,
    LibrarySource? source,
    ScanProgressCallback? onProgress,
    ScanCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? ScanCancellationToken();
    final rootDir = Directory(p.normalize(rootFolderPath));
    final libraryId =
        existingLibraryId ?? stableId(p.canonicalize(rootDir.path));
    final now = DateTime.now().millisecondsSinceEpoch;
    final catalog = MediaCatalogRepository(db);
    final namespace = source?.namespace ?? '';
    String sourcePath(String relative) => namespace.isEmpty ? relative : p.join(namespace, relative == '.' ? '' : relative);
    bool belongs(String relative) => namespace.isEmpty ? !relative.startsWith('@sources${p.separator}') : relative == namespace || p.isWithin(namespace, relative);

    if (!await rootDir.exists()) {
      final existing = await db.getLibraryById(libraryId);
      if (source != null) {
        await catalog.setSourceAvailability(source, true);
      } else if (existing != null) { await db.markLibraryUnavailable(libraryId, true); }
      throw FileSystemException(
        'The selected folder is no longer available.',
        rootDir.path,
      );
    }

    final existingLibrary = await db.getLibraryById(libraryId);

    final errors = <String>[];
    final unreadableDirectories = <String>{};
    final unreadableFiles = <String>{};
    var skipped = 0;
    final folders = <_FolderFiles>[];
    onProgress?.call(
      const ScanProgress(
        phase: 'Discovering files',
        discoveredFiles: 0,
        processedFiles: 0,
      ),
    );

    Future<void> visit(Directory directory) async {
      token.throwIfCancelled();
      final files = <File>[];
      final directories = <Directory>[];
      try {
        await for (final entity in directory.list(followLinks: false)) {
          token.throwIfCancelled();
          final name = p.basename(entity.path);
          if (_isIgnoredName(name)) {
            skipped++;
            if(entity is Directory) unreadableDirectories.add(p.normalize(entity.absolute.path));
            if(entity is File) unreadableFiles.add(p.normalize(entity.absolute.path));
            continue;
          }
          if (entity is Directory) {
            directories.add(entity);
          } else if (entity is File) {
            if (isSupportedImportFile(name)) {
              files.add(entity);
            } else {
              skipped++;
            }
          }
        }
      } on FileSystemException catch (error) {
        errors.add('${directory.path}: ${error.message}');
        unreadableDirectories.add(p.normalize(directory.absolute.path));
        return;
      }

      files.sort(
        (a, b) => naturalCourseCompare(p.basename(a.path), p.basename(b.path)),
      );
      directories.sort(
        (a, b) => naturalCourseCompare(p.basename(a.path), p.basename(b.path)),
      );
      if (files.isNotEmpty || directory.path != rootDir.path) {
        folders.add(_FolderFiles(directory, files));
      }
      for (final child in directories) {
        await visit(child);
      }
    }

    await visit(rootDir);
    if (unreadableDirectories.contains(p.normalize(rootDir.absolute.path))) {
      throw FileSystemException(
        'The selected folder cannot be read.',
        rootDir.path,
      );
    }
    final discoveredFiles = folders.fold<int>(
      0,
      (sum, folder) => sum + folder.files.length,
    );

    final allExistingItems = await db.getItemsForLibrary(libraryId);
    final existingItems = allExistingItems.where((item) => belongs(item.relativePath)).toList();
    final existingByPath = <String, Item>{};
    for (final item in existingItems) {
      final current = existingByPath[item.relativePath];
      if (current == null || (current.unavailable && !item.unavailable)) {
        existingByPath[item.relativePath] = item;
      }
    }
    final existingByFingerprint = <String, List<Item>>{};
    for (final item in existingItems) {
      final fingerprint = item.fingerprint;
      if (fingerprint != null && fingerprint.isNotEmpty) {
        existingByFingerprint.putIfAbsent(fingerprint, () => []).add(item);
      }
    }
    final discoveredPaths = {
      for (final folder in folders)
        for (final file in folder.files)
          sourcePath(p.relative(file.path, from: rootDir.path)),
    };
    final fingerprints = <String, String>{};
    final fingerprintCounts = <String, int>{};
    for (final folder in folders) {
      for (final file in folder.files) {
        token.throwIfCancelled();
        try {
          final atPath = existingByPath[sourcePath(p.relative(file.path, from: rootDir.path))];
          final stat=await file.stat();
          final cached=atPath?.fingerprint;
          final fingerprint=cached != null && cached.startsWith('sha256:') &&
            atPath!.fileSize == stat.size && atPath.modifiedAt == stat.modified.millisecondsSinceEpoch
            ? cached : await fingerprintFile(file,cancellationToken:token);
          fingerprints[file.path] = fingerprint;
          if (atPath?.fingerprint != fingerprint) {
            fingerprintCounts.update(
              fingerprint,
              (n) => n + 1,
              ifAbsent: () => 1,
            );
          }
          onProgress?.call(
            ScanProgress(
              phase: 'Verifying file identity',
              discoveredFiles: discoveredFiles,
              processedFiles: fingerprints.length,
              currentPath: file.path,
            ),
          );
        } on FileSystemException {
          // The indexing pass reports inaccessible files without deleting their history.
        }
      }
    }
    final claimedIds = <String>{};
    final sectionRows = <SectionsCompanion>[];
    final itemRows = <ItemsCompanion>[];
    final seenSectionIds = <String>{};
    final seenItemIds = <String>{};
    var processed = 0;

    for (var sectionIndex = 0; sectionIndex < folders.length; sectionIndex++) {
      token.throwIfCancelled();
      final folder = folders[sectionIndex];
      final relativeFolder = p.relative(
        folder.directory.path,
        from: rootDir.path,
      );
      final normalizedRelativeFolder = sourcePath(relativeFolder == '.' ? '' : relativeFolder);
      final sectionId = stableId(
        '$libraryId::section::$normalizedRelativeFolder',
      );
      final parentRelative = p.dirname(normalizedRelativeFolder);
      final parentId = normalizedRelativeFolder.isEmpty || parentRelative == '.'
          ? null
          : stableId('$libraryId::section::$parentRelative');
      seenSectionIds.add(sectionId);
      sectionRows.add(
        SectionsCompanion.insert(
          id: sectionId,
          libraryId: libraryId,
          title: normalizedRelativeFolder.isEmpty
              ? 'General'
              : p.basename(folder.directory.path),
          relativePath: drift.Value(normalizedRelativeFolder),
          parentSectionId: drift.Value(parentId),
          orderIndex: sectionIndex,
          folderPath: folder.directory.path,
          itemCount: drift.Value(folder.files.length),
          completedCount: const drift.Value(0),
          unavailable: const drift.Value(false),
          updatedAt: drift.Value(now),
        ),
      );

      for (var itemIndex = 0; itemIndex < folder.files.length; itemIndex++) {
        token.throwIfCancelled();
        final file = folder.files[itemIndex];
        try {
          final stat = await file.stat();
          final relativePath = sourcePath(p.relative(file.path, from: rootDir.path));
          final filename = p.basename(file.path);
          final fingerprint =
              fingerprints[file.path] ?? await fingerprintFile(file,cancellationToken:token);
          var existing = existingByPath[relativePath];
          if (existing?.fingerprint != null &&
              existing!.fingerprint != fingerprint) {
            final legacyMatches =
                !existing.fingerprint!.startsWith('sha256:') &&
                existing.modifiedAt == stat.modified.millisecondsSinceEpoch &&
                existing.fileSize == stat.size &&
                existing.fingerprint == await _legacyFingerprintFile(file);
            if (!legacyMatches) existing = null;
          }
          if (existing != null && claimedIds.contains(existing.id)) {
            existing = null;
          }
          if (existing == null && fingerprintCounts[fingerprint] == 1) {
            final candidates = existingByFingerprint[fingerprint]
                ?.where(
                  (candidate) =>
                      !claimedIds.contains(candidate.id) &&
                      !discoveredPaths.contains(candidate.relativePath),
                )
                .toList();
            if (candidates?.length == 1) existing = candidates!.single;
          }
          final itemId =
              existing?.id ??
              stableId('$libraryId::file::$fingerprint::$relativePath');
          claimedIds.add(itemId);
          seenItemIds.add(itemId);
          itemRows.add(
            ItemsCompanion.insert(
              id: itemId,
              libraryId: libraryId,
              sectionId: sectionId,
              title: existing?.title ?? p.basenameWithoutExtension(filename),
              userTitle: drift.Value(existing?.userTitle),
              filename: filename,
              filePath: file.path,
              relativePath: relativePath,
              itemType: inferItemType(filename).name,
              orderIndex: itemIndex,
              durationSeconds: drift.Value(existing?.durationSeconds),
              pageCount: drift.Value(existing?.pageCount),
              thumbnailPath: drift.Value(existing?.thumbnailPath),
              modifiedAt: drift.Value(stat.modified.millisecondsSinceEpoch),
              fileSize: drift.Value(stat.size),
              fingerprint: drift.Value(fingerprint),
              unavailable: const drift.Value(false),
              createdAt: drift.Value(existing?.createdAt ?? now),
              updatedAt: drift.Value(existing?.updatedAt ?? now),
              version: drift.Value(existing?.version ?? 1),
            ),
          );
        } on ScanCancelledException { rethrow;
        } catch (error) {
          errors.add('${file.path}: $error');
          unreadableFiles.add(p.normalize(file.absolute.path));
        }
        processed++;
        onProgress?.call(
          ScanProgress(
            phase: 'Indexing lessons',
            discoveredFiles: discoveredFiles,
            processedFiles: processed,
            currentPath: file.path,
          ),
        );
      }
    }

    token.throwIfCancelled();
    for (final item in existingItems) {
      final absolutePath = p.normalize(File(item.filePath).absolute.path);
      final insideUnreadableDirectory = unreadableDirectories.any(
        (directory) =>
            absolutePath == directory ||
            absolutePath.startsWith('$directory${Platform.pathSeparator}'),
      );
      if (insideUnreadableDirectory || unreadableFiles.contains(absolutePath)) {
        seenItemIds.add(item.id);
      }
    }
    final allExistingSections = await db.getSectionsForLibrary(libraryId);
    final existingSections = allExistingSections.where((section) => belongs(section.relativePath));
    for (final section in existingSections) {
      final absolutePath = p.normalize(
        Directory(section.folderPath).absolute.path,
      );
      final insideUnreadableDirectory = unreadableDirectories.any(
        (directory) =>
            absolutePath == directory ||
            absolutePath.startsWith('$directory${Platform.pathSeparator}') ||
            directory.startsWith('$absolutePath${Platform.pathSeparator}'),
      );
      if (insideUnreadableDirectory) seenSectionIds.add(section.id);
    }

    await LibrarySourceStore(db).stage(sessionId,itemRows);
    await db.transaction(() async {
      token.throwIfCancelled();
      await db.upsertLibrary(
        LibrariesCompanion.insert(
          id: libraryId,
          title: existingLibrary?.title ?? title,
          description: drift.Value(existingLibrary?.description ?? ''),
          rootFolderPath: namespace.isEmpty ? rootDir.path : existingLibrary!.rootFolderPath,
          coverPath: drift.Value(existingLibrary?.coverPath),
          createdAt: existingLibrary?.createdAt ?? now,
          updatedAt: existingLibrary?.updatedAt ?? now,
          lastScannedAt: drift.Value(existingLibrary?.lastScannedAt),
          unavailable: const drift.Value(false),
          version: drift.Value(existingLibrary?.version ?? 1),
          updatedByDevice: drift.Value(
            existingLibrary?.updatedByDevice ?? 'local',
          ),
        ),
      );
      await db.applyScan(
        libraryId: libraryId,
        scannedSections: sectionRows,
        scannedItems: itemRows,
        seenSectionIds: {...seenSectionIds, ...allExistingSections.where((s) => !belongs(s.relativePath)).map((s) => s.id)},
        seenItemIds: {...seenItemIds, ...allExistingItems.where((i) => !belongs(i.relativePath)).map((i) => i.id)},
      );
      await db.customStatement('INSERT OR IGNORE INTO library_sources(id,library_id,root_path,namespace,updated_at) VALUES(?,?,?,?,?)',
        [source?.id ?? 'legacy:$libraryId',libraryId,rootDir.path,namespace,now]);
      await CatalogIdentityStore(db).backfill();
      for(final row in itemRows) {
        final item=await db.getItemById(row.id.value);
        if(item != null) await LibrarySourceStore(db).bind(item,source?.id ?? 'legacy:$libraryId',p.relative(row.filePath.value,from:rootDir.path));
      }
    });
    if (source != null) await catalog.setSourceAvailability(source, false);
    if (namespace.isEmpty) await db.customStatement('UPDATE library_sources SET root_path = ?, unavailable = 0 WHERE id = ?', [rootDir.path, 'legacy:$libraryId']);
    final missingItems = existingItems
        .where((item) => !seenItemIds.contains(item.id))
        .length;
    onProgress?.call(
      ScanProgress(
        phase: 'Complete',
        discoveredFiles: discoveredFiles,
        processedFiles: processed,
      ),
    );
    return ScanResult(
      libraryId: libraryId,
      importedItems: itemRows.length,
      missingItems: missingItems,
      skippedFiles: skipped,
      errors: errors,
      outcome: errors.isEmpty ? 'complete' : 'partial',
    );
  }
}

class _FolderFiles {
  const _FolderFiles(this.directory, this.files);

  final Directory directory;
  final List<File> files;
}

bool _isIgnoredName(String name) {
  final lower = name.toLowerCase();
  return name.startsWith('.') ||
      name.startsWith('~') ||
      lower == 'thumbs.db' ||
      lower == 'desktop.ini' ||
      lower == '.nomedia' ||
      lower == '__macosx' ||
      lower.endsWith('.tmp') ||
      lower.endsWith('.part') ||
      lower.endsWith('.crdownload');
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override void add(Digest data) {value=data;}
  @override void close() {}
}
Future<String> fingerprintFile(File file,{ScanCancellationToken? cancellationToken}) async {
  final output=_DigestSink();
  final sink=sha256.startChunkedConversion(output);
  try {
    await for(final chunk in file.openRead()) {
      cancellationToken?.throwIfCancelled();
      sink.add(chunk);
    }
    cancellationToken?.throwIfCancelled();
  } finally {sink.close();}
  return 'sha256:${output.value}';
}

Future<String> _legacyFingerprintFile(
  File file, {
  int sampleSize = 64 * 1024,
}) async {
  final stat = await file.stat();
  final handle = await file.open();
  try {
    final firstLength = stat.size < sampleSize ? stat.size : sampleSize;
    final first = await handle.read(firstLength);
    Uint8List last = Uint8List(0);
    if (stat.size > sampleSize) {
      await handle.setPosition((stat.size - sampleSize).clamp(0, stat.size));
      last = await handle.read(sampleSize);
    }
    final sink = <int>[...first, ...last, ...stat.size.toString().codeUnits];
    return sha256.convert(sink).toString();
  } finally {
    await handle.close();
  }
}
