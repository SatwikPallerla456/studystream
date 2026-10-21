import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import '../indexer/library_source_store.dart';

import '../../domain/catalog/media_catalog_repository.dart';
import '../db/app_database.dart';

class MediaSourceException implements Exception {
  const MediaSourceException(this.statusCode, this.message);
  final int statusCode;
  final String message;
}

/// Compatibility resolver until items carry an explicit source relationship.
/// Namespace ownership selects exactly one approved source, never any root that
/// happens to contain the current file path.
Future<File> resolveApprovedMedia(AppDatabase database, Item item) async {
  final library = await database.getLibraryById(item.libraryId);
  if (library == null ||
      library.rootFolderPath.startsWith('remote:') ||
      library.rootFolderPath.startsWith('import:')) {
    throw const MediaSourceException(
      HttpStatus.notFound,
      'Library unavailable',
    );
  }
  if (!p.isAbsolute(item.filePath) ||
      p.isAbsolute(item.relativePath) ||
      p.split(item.relativePath).contains('..')) {
    throw const MediaSourceException(
      HttpStatus.forbidden,
      'File is outside the approved source',
    );
  }
  final relative = p.normalize(item.relativePath);
  final sources = await MediaCatalogRepository(database).sources(library.id);
  final secondary =
      relative == '@sources' || relative.startsWith('@sources${p.separator}');
  final binding = await database
      .customSelect(
        'SELECT * FROM item_assets WHERE item_id = ?',
        variables: [Variable(item.id)],
      )
      .getSingleOrNull();
  final owners = sources
      .where(
        (source) => binding != null
            ? source.id == binding.data['source_id']
            : secondary
            ? source.namespace.isNotEmpty &&
                  p.isWithin(source.namespace, relative)
            : source.namespace.isEmpty,
      )
      .toList();
  if (owners.length != 1) {
    throw const MediaSourceException(
      HttpStatus.forbidden,
      'Media source ownership is ambiguous or missing',
    );
  }
  final source = owners.single;
  if (source.unavailable || !p.isAbsolute(source.root)) {
    throw const MediaSourceException(
      HttpStatus.notFound,
      'Media source unavailable',
    );
  }
  try {
    final canonicalRoot = await Directory(source.root).resolveSymbolicLinks();
    final canonicalFile = await File(item.filePath).resolveSymbolicLinks();
    if (!p.isWithin(canonicalRoot, canonicalFile)) {
      throw const MediaSourceException(
        HttpStatus.forbidden,
        'File is outside the approved source',
      );
    }
    final file = File(canonicalFile);
    if (!await file.exists()) {
      throw const MediaSourceException(
        HttpStatus.notFound,
        'Media unavailable',
      );
    }
    if (binding == null)
      await LibrarySourceStore(
        database,
      ).bind(item, source.id, p.relative(item.filePath, from: source.root));
    return file;
  } on FileSystemException {
    throw const MediaSourceException(
      HttpStatus.notFound,
      'Media source unavailable',
    );
  }
}
