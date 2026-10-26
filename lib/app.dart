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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
