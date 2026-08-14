import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as p;

import '../../core/constants/supported_extensions.dart';
import '../../core/utils/id_utils.dart';
import '../../core/utils/sort_utils.dart';
import '../db/app_database.dart';

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
  });

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
    ScanProgressCallback? onProgress,
    ScanCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? ScanCancellationToken();
    final rootDir = Directory(p.normalize(rootFolderPath));
    final libraryId = stableId(p.canonicalize(rootDir.path));
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!await rootDir.exists()) {
      final existing = await db.getLibraryById(libraryId);
      if (existing != null) await db.markLibraryUnavailable(libraryId, true);
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
      if (files.isNotEmpty) folders.add(_FolderFiles(directory, files));
      for (final child in directories) {
        await visit(child);
      }
    }

    await visit(rootDir);
    final discoveredFiles = folders.fold<int>(
      0,
      (sum, folder) => sum + folder.files.length,
    );

    final existingItems = await db.getItemsForLibrary(libraryId);
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
      final normalizedRelativeFolder = relativeFolder == '.'
          ? ''
          : relativeFolder;
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
          final relativePath = p.relative(file.path, from: rootDir.path);
          final filename = p.basename(file.path);
          final fingerprint = await fingerprintFile(file);
          var existing = existingByPath[relativePath];
          if (existing?.fingerprint != null &&
              existing!.fingerprint != fingerprint) {
            existing = null;
          }
          if (existing == null) {
            final candidates = existingByFingerprint[fingerprint]
                ?.where((candidate) => !claimedIds.contains(candidate.id))
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
              updatedAt: drift.Value(now),
              version: drift.Value(existing?.version ?? 1),
            ),
          );
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
    final existingSections = await db.getSectionsForLibrary(libraryId);
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

    await db.upsertLibrary(
      LibrariesCompanion.insert(
        id: libraryId,
        title: existingLibrary?.title ?? title,
        description: drift.Value(existingLibrary?.description ?? ''),
        rootFolderPath: rootDir.path,
        coverPath: drift.Value(existingLibrary?.coverPath),
        createdAt: existingLibrary?.createdAt ?? now,
        updatedAt: now,
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
      seenSectionIds: seenSectionIds,
      seenItemIds: seenItemIds,
    );
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

Future<String> fingerprintFile(File file, {int sampleSize = 64 * 1024}) async {
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
