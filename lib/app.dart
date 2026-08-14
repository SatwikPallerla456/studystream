import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'data/providers/app_providers.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/player/media_player_screen.dart';
import 'features/reader/pdf_reader_screen.dart';
import 'features/resource/resource_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/library/:libraryId',
      builder: (context, state) =>
          LibraryScreen(libraryId: state.pathParameters['libraryId']!),
    ),
    GoRoute(
      path: '/player/:itemId',
      builder: (context, state) => MediaPlayerScreen(
        itemId: state.pathParameters['itemId']!,
        initialPositionSeconds: double.tryParse(
          state.uri.queryParameters['position'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/pdf/:itemId',
      builder: (context, state) => PdfReaderScreen(
        itemId: state.pathParameters['itemId']!,
        initialPage: int.tryParse(state.uri.queryParameters['page'] ?? ''),
      ),
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
      title: 'StudyStream',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
