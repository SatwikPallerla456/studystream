// Manual screenshot harness. Not imported by lib/main.dart, not an automated
// test, and never opens the user's database, source folders or paired devices.
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
    LibraryKind.television,
    LibraryKind.music,
    LibraryKind.books,
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
        type = kind == LibraryKind.television
            ? 'video'
            : kind == LibraryKind.music
            ? 'audio'
            : 'epub';
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
            relativePath: '$id',
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

  await item(LibraryKind.television, 'A Winter Letter', {
    'show': 'Signal Coast',
    'season': 0,
    'episode': 1,
  });
  await item(
    LibraryKind.television,
    'Arrival',
    {'show': 'Signal Coast', 'season': 1, 'episode': 1},
    progress: 100,
    complete: true,
  );
  await item(LibraryKind.television, 'Night Shift', {
    'show': 'Signal Coast',
    'season': 1,
    'episode': 2,
  }, progress: 38);
  await item(LibraryKind.television, 'Crossing / Homeward', {
    'show': 'Signal Coast',
    'season': 1,
    'episode': 3,
    'episodeEnd': 4,
  });
  await item(LibraryKind.television, 'New Tide', {
    'show': 'Signal Coast',
    'season': 2,
    'episode': 1,
  });
  await item(LibraryKind.television, 'Unidentified recording', {});
  await item(LibraryKind.music, 'First Light', {
    'artist': 'Mira Lane',
    'album': 'Daybreak',
    'disc': 1,
    'track': 1,
  });
  await item(LibraryKind.music, 'Open Windows', {
    'artist': 'Mira Lane',
    'album': 'Daybreak',
    'disc': 1,
    'track': 2,
  }, progress: 24);
  await item(LibraryKind.music, 'Afterglow', {
    'artist': 'Mira Lane',
    'album': 'Daybreak',
    'disc': 2,
    'track': 1,
  });
  await item(LibraryKind.music, 'Harbor', {
    'artist': 'Mira Lane',
    'album': 'Coastlines',
    'disc': 1,
    'track': 1,
  });
  await item(LibraryKind.music, 'Another Dawn', {
    'artist': 'North Assembly',
    'album': 'Daybreak',
    'disc': 1,
    'track': 1,
  });
  await item(LibraryKind.music, 'Untitled audio', {});
  await item(LibraryKind.books, 'Juniper Atlas I', {
    'author': 'Ari Vale',
    'series': 'The Atlas Cycle',
    'volume': 1,
  }, progress: 45);
  await item(LibraryKind.books, 'Juniper Atlas II', {
    'author': 'Ari Vale',
    'series': 'The Atlas Cycle',
    'volume': 2,
  });
  await item(
    LibraryKind.books,
    'A Small History',
    {'author': 'R. West'},
    progress: 100,
    complete: true,
  );
  await item(LibraryKind.books, 'Unidentified book', {});
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
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Category design preview')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 16,
              children: [
                for (final kind in [
                  LibraryKind.television,
                  LibraryKind.music,
                  LibraryKind.books,
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
