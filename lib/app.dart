import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'data/providers/app_providers.dart';
import 'features/setup/device_home.dart';
import 'features/setup/mode_selection_screen.dart';
import 'features/server/server_screen.dart';
import 'features/server/network_screen.dart';
import 'features/library/library_screen.dart';
import 'features/library/library_sources_screen.dart';
import 'features/library/media_category_screen.dart';
import 'features/library/photo_slideshow_screen.dart';
import 'features/library/library_identification_screen.dart';
import 'features/study/study_screen.dart';
import 'domain/catalog/media_catalog_repository.dart';
import 'features/media/media_details_screen.dart';
import 'features/media/media_browse_screen.dart';
import 'features/player/media_player_screen.dart';
import 'features/reader/pdf_reader_screen.dart';
import 'features/reader/book_reader_screen.dart';
import 'features/resource/resource_screen.dart';
import 'features/playlists/playlists_screen.dart';
import 'features/settings/player_controls_screen.dart';
import 'features/player/advanced_player_screen.dart';
import 'features/music/music_library_screen.dart';
import 'features/music/music_player_screen.dart';
import 'features/music/music_provider.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) =>
          state.uri.queryParameters['tab'] == 'notes' ? '/study' : null,
      builder: (context, state) =>
          DeviceHome(tab: state.uri.queryParameters['tab']),
    ),
    GoRoute(
      path: '/music',
      builder: (_, state) => MusicLibraryScreen(
        initialTab: state.uri.queryParameters['artist'] == null ? 0 : 2,
        artist: state.uri.queryParameters['artist'],
      ),
    ),
    GoRoute(
      path: '/listen/:itemId',
      builder: (_, state) => MusicPlayerScreen(
        key: ValueKey(state.uri.toString()),
        itemId: state.pathParameters['itemId']!,
        fromQueue: state.uri.queryParameters['queue'] == '1',
        radio: state.uri.queryParameters['radio'] == '1',
      ),
    ),
    GoRoute(path: '/study', builder: (_, _) => const StudyScreen()),
    GoRoute(
      path: '/category/:kind',
      builder: (context, state) => MediaCategoryScreen(
        kind: LibraryKind.values.firstWhere(
          (kind) => kind.name == state.pathParameters['kind'],
          orElse: () => LibraryKind.mixed,
        ),
      ),
    ),
    GoRoute(
      path: '/library/:libraryId/identify',
      builder: (context, state) => LibraryIdentificationScreen(
        libraryId: state.pathParameters['libraryId']!,
      ),
    ),
    GoRoute(
      path: '/mode',
      builder: (context, state) => const ModeSelectionScreen(),
    ),
    GoRoute(
      path: '/advanced-player',
      builder: (_, _) => const AdvancedPlayerScreen(),
    ),
    GoRoute(
      path: '/player-settings',
      builder: (context, state) => const PlayerControlsScreen(),
    ),
    GoRoute(
      path: '/playlists',
      builder: (context, state) =>
          PlaylistsScreen(currentItemId: state.uri.queryParameters['current']),
    ),
    GoRoute(path: '/server', builder: (context, state) => const ServerScreen()),
    GoRoute(
      path: '/network',
      builder: (context, state) => const NetworkScreen(),
    ),
    GoRoute(
      path: '/library/:libraryId/sources',
      builder: (context, state) =>
          LibrarySourcesScreen(libraryId: state.pathParameters['libraryId']!),
    ),
    GoRoute(
      path: '/library/:libraryId',
      builder: (context, state) =>
          LibraryScreen(libraryId: state.pathParameters['libraryId']!),
    ),
    GoRoute(
      path: '/browse',
      builder: (context, state) => const MediaBrowseScreen(),
    ),
    GoRoute(
      path: '/details/:itemId',
      builder: (context, state) =>
          MediaDetailsScreen(itemId: state.pathParameters['itemId']!),
    ),
    GoRoute(
      path: '/player/:itemId',
      redirect: (context, state) async {
        if (state.uri.queryParameters['native'] == '1') return null;
        final db = ProviderScope.containerOf(context).read(appDatabaseProvider),
            item = await ProviderScope.containerOf(context)
                .read(appDatabaseProvider)
                .getItemById(state.pathParameters['itemId']!);
        if (item != null &&
            item.itemType == 'audio' &&
            await MediaCatalogRepository(db).libraryKind(item.libraryId) ==
                LibraryKind.music)
          return Uri(
            path: '/listen/${item.id}',
            queryParameters: state.uri.queryParameters,
          ).toString();
        return null;
      },
      builder: (context, state) => MediaPlayerScreen(
        key: ValueKey(state.uri.toString()),
        multipartRepresentationId: state.uri.queryParameters['title'],
        itemId: state.pathParameters['itemId']!,
        fromQueue: state.uri.queryParameters['queue'] == '1',
        initialPositionSeconds: double.tryParse(
          state.uri.queryParameters['position'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/book/:itemId',
      builder: (context, state) => BookReaderScreen(
        itemId: state.pathParameters['itemId']!,
        initialPage: int.tryParse(state.uri.queryParameters['page'] ?? ''),
        initialStudyAnchor: state.uri.queryParameters['study'],
      ),
    ),
    GoRoute(
      path: '/pdf/:itemId',
      builder: (context, state) => PdfReaderScreen(
        itemId: state.pathParameters['itemId']!,
        initialPage: int.tryParse(state.uri.queryParameters['page'] ?? ''),
        initialStudyAnchor: state.uri.queryParameters['study'],
      ),
    ),
    GoRoute(
      path: '/photo/:itemId',
      builder: (context, state) =>
          PhotoSlideshowScreen(initialItemId: state.pathParameters['itemId']!),
    ),
    GoRoute(
      path: '/resource/:itemId',
      builder: (context, state) =>
          ResourceScreen(itemId: state.pathParameters['itemId']!),
    ),
  ],
);

class StudyMediaPlayerApp extends ConsumerWidget {
  const StudyMediaPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Tangerine',
      builder: (context, child) => ListenableBuilder(
        listenable: _router.routeInformationProvider,
        builder: (context, _) => Column(
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            if (!_router.routeInformationProvider.value.uri.path.startsWith(
              '/listen/',
            ))
              MusicDock(
                onOpen: () {
                  final item = ref.read(musicSessionProvider)?.track?.item;
                  if (item != null)
                    _router.push('/listen/${Uri.encodeComponent(item.id)}');
                },
              ),
          ],
        ),
      ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
