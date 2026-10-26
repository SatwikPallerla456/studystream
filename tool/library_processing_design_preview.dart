// Manual screenshot harness. Not imported by lib/main.dart, not an automated
// test, and never opens the user's database, source folders or paired devices.
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../lib/core/theme/app_theme.dart';
import '../lib/data/db/app_database.dart';
import '../lib/data/providers/app_providers.dart';
import '../lib/domain/catalog/catalog_identity_store.dart';
import '../lib/domain/catalog/media_catalog_repository.dart';
import '../lib/features/library/media_category_screen.dart';
import '../lib/features/library/library_screen.dart';
import '../lib/features/media/media_details_screen.dart';
import '../lib/domain/catalog/library_processing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customSelect('SELECT 1').get();
  final catalog = MediaCatalogRepository(db);
  final seeds =
      <
        ({
          String id,
          Map<String, dynamic> metadata,
          double progress,
          bool complete,
        })
      >[];
  var serial = 0;
  for (final kind in [
    LibraryKind.audiobooks,
    LibraryKind.podcasts,
    LibraryKind.photos,
    LibraryKind.homeVideos,
    LibraryKind.musicVideos,
    LibraryKind.documents,
  ]) {
    final id = 'preview-${kind.name}';
    await db
        .into(db.libraries)
        .insert(
          LibrariesCompanion.insert(
            id: id,
            title: 'Preview ${kind.label}',
            rootFolderPath: '/design-preview-only',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.sections)
        .insert(
          SectionsCompanion.insert(
            id: id,
            libraryId: id,
            title: 'Preview',
            orderIndex: 0,
            folderPath: '/design-preview-only',
          ),
        );
    await catalog.setLibraryKind(id, kind);
  }
  Future<void> item(
    LibraryKind kind,
    String title,
    Map<String, dynamic> metadata, {
    double progress = 0,
    bool complete = false,
  }) async {
    final id = 'preview-item-${serial++}',
        library = 'preview-${kind.name}',
        type = switch (kind) {
          LibraryKind.audiobooks || LibraryKind.podcasts => 'audio',
          LibraryKind.photos => 'image',
          LibraryKind.documents => 'pdf',
          _ => 'video',
        };
    await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            id: id,
            libraryId: library,
            sectionId: library,
            title: title,
            filename:
                '$title.${type == 'video'
                    ? 'mkv'
                    : type == 'audio'
                    ? 'mp3'
                    : 'epub'}',
            filePath: '/design-preview-only/$id',
            relativePath:
                '${kind == LibraryKind.photos
                    ? 'Holiday'
                    : kind == LibraryKind.documents
                    ? 'Reference'
                    : 'Recordings'}/$title.${type == 'image'
                    ? 'jpg'
                    : type == 'pdf'
                    ? 'pdf'
                    : type == 'audio'
                    ? 'm4b'
                    : 'mp4'}',
            modifiedAt: const Value(1790128800000),
            fileSize: const Value(1024),
            fingerprint: Value(id),
            itemType: type,
            orderIndex: serial,
            durationSeconds: type == 'epub'
                ? const Value.absent()
                : Value(type == 'video' ? 2400.0 : 212.0),
          ),
        );
    seeds.add((
      id: id,
      metadata: {'title': title, ...metadata},
      progress: progress,
      complete: complete,
    ));
  }

  await item(LibraryKind.audiobooks, 'First light', {
    'author': 'Ari Vale',
    'series': 'The Atlas Cycle',
    'disc': 1,
    'track': 1,
  }, progress: 32);
  await item(LibraryKind.audiobooks, 'The crossing', {
    'author': 'Ari Vale',
    'series': 'The Atlas Cycle',
    'disc': 1,
    'track': 2,
  });
  await item(LibraryKind.audiobooks, 'A new horizon', {
    'author': 'R. West',
    'series': 'The Atlas Cycle',
    'track': 1,
  });
  await item(LibraryKind.audiobooks, 'Untitled recording', {});
  await item(LibraryKind.podcasts, 'Reading the city', {
    'series': 'Open Windows',
    'track': 23,
    'airDate': '2026-09-24',
  });
  await item(LibraryKind.podcasts, 'Libraries after dark', {
    'series': 'Open Windows',
    'track': 22,
    'airDate': '2026-09-17',
  }, progress: 54);
  await item(LibraryKind.podcasts, 'Unidentified episode', {});
  await item(LibraryKind.photos, 'Morning by the coast', {});
  await item(LibraryKind.photos, 'A quiet street', {});
  await item(LibraryKind.homeVideos, 'Summer walk', {});
  await item(LibraryKind.homeVideos, 'Family dinner', {});
  await item(LibraryKind.musicVideos, 'Daybreak', {'artist': 'Mira Lane'});
  await item(LibraryKind.musicVideos, 'Untitled video', {});
  await item(LibraryKind.documents, 'A field guide', {'author': 'Ari Vale'});
  await item(LibraryKind.documents, 'Course reference', {});
  await CatalogIdentityStore(db).backfill();
  for (final seed in seeds) {
    final media = (await db.getItemById(seed.id))!;
    await catalog.saveMetadata(media, seed.metadata);
    if (media.itemType == 'epub') {
      await db
          .into(db.readingProgress)
          .insert(
            ReadingProgressCompanion.insert(
              itemId: media.id,
              percentRead: Value(seed.progress),
              completed: Value(seed.complete),
              deviceId: 'design-preview',
            ),
          );
    } else {
      await db
          .into(db.playbackProgress)
          .insert(
            PlaybackProgressCompanion.insert(
              itemId: media.id,
              percentWatched: Value(seed.progress),
              completed: Value(seed.complete),
              deviceId: 'design-preview',
            ),
          );
    }
  }
  // Display durable queue snapshots without starting or executing the worker.
  final processing = LibraryProcessingStore(db);
  var job = 0;
  for (final seed in seeds) {
    final media = (await db.getItemById(seed.id))!;
    await processing.enqueue(media);
    await db.customStatement(
      'UPDATE library_processing_jobs SET state=? WHERE item_id=? AND kind=?',
      [
        ['complete', 'queued', 'failed', 'deferred'][job++ % 4],
        media.id,
        'analyze',
      ],
    );
  }
  await db.customStatement(
    'INSERT INTO technical_media(id,library_id,item_id,content_revision,analysis_version,payload,updated_at) VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,content_revision=excluded.content_revision',
    [
      seeds.first.id,
      'preview-audiobooks',
      seeds.first.id,
      seeds.first.id,
      3,
      jsonEncode({
        'analysisState': 'complete',
        'container': 'm4b',
        'durationSeconds': 3720,
        'streams': [
          {
            'id': 1,
            'kind': 'audio',
            'codec': 'aac',
            'channels': 2,
            'sampleRate': 44100,
          },
        ],
        'chapters': [
          {'title': 'First light', 'startSeconds': 0},
          {'title': 'The crossing', 'startSeconds': 1200},
          {'title': 'A new horizon', 'startSeconds': 2400},
        ],
      }),
      0,
    ],
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Library processing design preview'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 16,
              children: [
                for (final kind in [
                  LibraryKind.audiobooks,
                  LibraryKind.podcasts,
                  LibraryKind.photos,
                  LibraryKind.homeVideos,
                  LibraryKind.musicVideos,
                  LibraryKind.documents,
                ])
                  FilledButton(
                    onPressed: () => context.push('/category/${kind.name}'),
                    child: Text(kind.label),
                  ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/category/:kind',
        builder: (_, state) => MediaCategoryScreen(
          kind: LibraryKind.values.byName(state.pathParameters['kind']!),
        ),
      ),
      GoRoute(
        path: '/library/:id',
        builder: (_, state) =>
            LibraryScreen(libraryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/details/:id',
        builder: (_, state) =>
            MediaDetailsScreen(itemId: state.pathParameters['id']!),
      ),
    ],
  );
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => Column(
          children: [
            Material(
              color: Colors.amber.shade100,
              child: const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'DESIGN PREVIEW · synthetic catalog · no user data or playable media',
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ),
            Expanded(child: child!),
          ],
        ),
      ),
    ),
  );
}
