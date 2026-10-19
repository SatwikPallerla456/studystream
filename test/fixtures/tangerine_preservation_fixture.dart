import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/domain/catalog/media_catalog_repository.dart';

/// Synthetic P0 preservation inventory: no personal media or credentials.
Future<void> seedTangerinePreservation(
  AppDatabase db, {
  required String legacyRoot,
  required String secondaryRoot,
}) async {
  for (final (id, root) in [
    ('local', legacyRoot),
    ('mirror', 'remote:fixture'),
    ('imports', 'import:fixture'),
  ]) {
    await db.upsertLibrary(
      LibrariesCompanion.insert(
        id: id,
        title: '$id library',
        rootFolderPath: root,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await db.upsertSection(
      SectionsCompanion.insert(
        id: '$id-section',
        libraryId: id,
        title: '$id section',
        orderIndex: 0,
        folderPath: root,
      ),
    );
    for (final (suffix, type, name) in [
      ('video', 'video', 'movie.mp4'),
      ('book', 'pdf', 'book.pdf'),
    ]) {
      final secondary = id == 'local';
      await db.upsertItem(
        ItemsCompanion.insert(
          id: '$id-$suffix',
          libraryId: id,
          sectionId: '$id-section',
          title: '$id $suffix',
          filename: name,
          filePath: secondary ? '$secondaryRoot/$name' : '$root/$name',
          relativePath: secondary ? '@sources/secondary/$name' : name,
          itemType: type,
          orderIndex: suffix == 'video' ? 0 : 1,
          fingerprint: const Value('sha256:synthetic-preservation-fingerprint'),
        ),
      );
    }
    await db.upsertPlayback(
      PlaybackProgressCompanion.insert(
        itemId: '$id-video',
        lastPositionSeconds: const Value(47),
        resumePositionSeconds: const Value(42),
        percentWatched: const Value(47),
        manualCompletion: const Value(false),
        durationSeconds: const Value(100),
        lastOpenedAt: const Value(100),
        lastEventAt: const Value(101),
        deviceId: 'fixture',
      ),
    );
    await db.upsertReading(
      ReadingProgressCompanion.insert(
        itemId: '$id-book',
        lastPage: const Value(7),
        resumePage: const Value(6),
        lastScrollOffset: const Value(120),
        resumeScrollOffset: const Value(80),
        zoom: const Value(1.5),
        readingMode: const Value('vertical'),
        manualCompletion: const Value(true),
        completed: const Value(true),
        lastOpenedAt: const Value(102),
        lastEventAt: const Value(103),
        deviceId: 'fixture',
      ),
    );
    await db.upsertNote(
      NotesCompanion.insert(
        id: '$id-note',
        libraryId: id,
        itemId: Value('$id-book'),
        pageNumber: const Value(6),
        content: '$id page note',
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'fixture',
      ),
    );
    await db.upsertBookmark(
      BookmarksCompanion.insert(
        id: '$id-bookmark',
        libraryId: id,
        itemId: '$id-video',
        title: '$id bookmark',
        positionSeconds: const Value(42),
        createdAt: 1,
        updatedAt: 2,
        deviceId: 'fixture',
      ),
    );
    final catalog = MediaCatalogRepository(db);
    await catalog.setLibraryKind(id, LibraryKind.movies);
    await catalog.save('metadata:$id-video', 'metadata', id, {
      'title': '$id catalog title',
      'year': 2026,
      'matchState': 'unmatched',
      'source': 'filename',
      'localExtension': {'original': '$root/private.json'},
    }, itemId: '$id-video');
    await catalog.setFavorite((await db.getItemById('$id-video'))!, true);
    await catalog.saveCollection(id, '$id collection', [
      '$id-video',
    ], id: '$id-collection');
    await catalog.save('reader:$id-book', 'reader', id, {
      'rtl': false,
      'mode': 'vertical',
      'background': 'white',
      'fit': 'contain',
      'fontSize': 20,
      'lineHeight': 1.6,
      'locator': 'chapter-6',
    }, itemId: '$id-book');
  }
  await db.customStatement(
    'INSERT INTO library_sources(id,library_id,root_path,namespace,unavailable,updated_at) VALUES(?,?,?,?,?,?)',
    ['secondary', 'local', secondaryRoot, '@sources/secondary', 0, 1],
  );
  await db.customStatement(
    'INSERT INTO library_sources(id,library_id,root_path,namespace,unavailable,updated_at) VALUES(?,?,?,?,?,?)',
    ['legacy:local', 'local', legacyRoot, '', 1, 1],
  );
  await db.setSetting('myvlc.queue', jsonEncode(['local-video']));
  await db.setSetting(
    'myvlc.playlists',
    jsonEncode({
      'fixture-playlist': {
        'id': 'fixture-playlist',
        'title': 'Fixture playlist',
        'itemIds': ['local-video'],
      },
    }),
  );
  await db.setSetting(
    'player.item.local-video',
    jsonEncode({
      'subtitlePath': '$secondaryRoot/movie.srt',
      'audioDelayMs': 250,
    }),
  );
  await db.setSetting('sync.fixturePermission', legacyRoot);
}
