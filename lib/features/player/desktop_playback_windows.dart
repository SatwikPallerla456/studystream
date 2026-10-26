import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/services/player_library_repository.dart';
import '../media/media_details_screen.dart';
import '../playlists/playlists_screen.dart';
import '../settings/player_controls_screen.dart';
import 'media_player_screen.dart';

final independentPlaybackWindowProvider = Provider<bool>((ref) => false);

abstract final class DesktopPlaybackWindows {
  static bool get available =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  static Future<void> showLibrary() async {
    for (final window in await WindowController.getAll()) {
      if (!window.arguments.contains('"type":"player"')) {
        await window.show();
        await window.invokeMethod<dynamic>('showWindow');
        return;
      }
    }
    throw StateError('The library window has closed.');
  }

  static Future<void> Function()? prepareExit;
  static Future<dynamic> Function(MethodCall)? appActionHandler;
  static Future<void> notifyTrack(String title, bool minimized) async {
    final windows = await WindowController.getAll();
    for (final window in windows) {
      if (!window.arguments.contains('"type":"player"')) {
        await window.invokeMethod<dynamic>('trackChanged', {
          'title': title,
          'minimized': minimized,
        });
        return;
      }
    }
  }

  static Future<void> installExitHandler() async {
    final window = await WindowController.fromCurrentEngine();
    await window.setWindowMethodHandler((call) async {
      if (call.method == 'prepareExit') {
        await prepareExit?.call();
        return true;
      }
      if (appActionHandler != null) return appActionHandler!(call);
      throw MissingPluginException();
    });
  }

  static Future<void> prepareOtherWindowsForExit() async {
    final current = await WindowController.fromCurrentEngine();
    for (final window in await WindowController.getAll()) {
      if (window.windowId != current.windowId)
        await window
            .invokeMethod<bool>('prepareExit')
            .timeout(const Duration(seconds: 5));
    }
  }

  static Future<void> _openTail = Future.value();
  static Future<void> open(
    String itemId, {
    AppDatabase? database,
    double? position,
    bool fromQueue = false,
    String? title,
  }) async {
    if (!available)
      throw UnsupportedError('Independent playback windows require a desktop.');
    final current = await WindowController.fromCurrentEngine();
    Map args = {};
    if (current.arguments.isNotEmpty)
      args = jsonDecode(current.arguments) as Map;
    Map<String, dynamic>? queue;
    if (database != null && fromQueue) {
      queue =
          (await PlayerLibraryRepository(
              database,
              queueNamespace: args['type'] == 'player'
                  ? args['session'] as String?
                  : null,
            ).load()).toJson()
            ..remove('playlists')
            ..remove('deletedPlaylistIds');
    }
    final request = <String, dynamic>{
      'item': itemId,
      if (position != null && position.isFinite && position >= 0)
        'position': position,
      if (fromQueue) 'queue': true,
      if (title != null) 'title': title,
      if (queue != null) 'queueState': queue,
    };
    if (args['type'] == 'player') {
      for (final window in await WindowController.getAll()) {
        if (!window.arguments.contains('"type":"player"')) {
          await window.invokeMethod<dynamic>('openPlayer', request);
          return;
        }
      }
      throw StateError(
        'Reopen the primary library window before opening another player.',
      );
    }
    await openInPrimary(request, database);
  }

  /// Serial admission in the primary engine prevents simultaneous child-window
  /// requests from bypassing the process-wide eight-player limit.
  static Future<void> openInPrimary(
    Map<String, dynamic> request,
    AppDatabase? database,
  ) {
    final opening = _openTail.then((_) async {
      if ((await WindowController.getAll()).length >= 9)
        throw const FormatException(
          'Close a playback window before opening another (maximum eight).',
        );
      final item = request['item'];
      if (item is! String || item.isEmpty || item.length > 256)
        throw const FormatException('Invalid playback item.');
      final session = const Uuid().v4();
      final queue = request['queueState'];
      if (queue != null && database != null) {
        final state = PlayerLibraryState.fromJson(queue as Map);
        if (state.queue.length > 10000)
          throw const FormatException('Playback queue exceeds 10,000 entries.');
        await database.setSetting(
          'player.window.queue:$session',
          jsonEncode(
            state.toJson()
              ..remove('playlists')
              ..remove('deletedPlaylistIds'),
          ),
        );
      }
      try {
        final window = await WindowController.create(
          WindowConfiguration(
            arguments: jsonEncode({
              'type': 'player',
              'item': item,
              'session': session,
              if (request['position'] is num) 'position': request['position'],
              if (request['queue'] == true) 'queue': true,
              if (request['title'] is String) 'title': request['title'],
            }),
            hiddenAtLaunch: true,
          ),
        );
        await window.show();
      } catch (_) {
        if (database != null)
          await (database.delete(
                database.appSettings,
              )..where((row) => row.key.equals('player.window.queue:$session')))
              .go();
        rethrow;
      }
    });
    _openTail = opening.catchError((Object _) {});
    return opening;
  }
}

/// Only the primary engine runs scans/analysis. Child windows hold that work and
/// publish database invalidations back to the primary engine while they exist.
class DesktopPlayerCoordinator {
  DesktopPlayerCoordinator(this.ref) {
    unawaited(DesktopPlaybackWindows.installExitHandler());
    _changes = onWindowsChanged.listen((_) {
      unawaited(_refresh());
    });
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refresh());
    });
    unawaited(_refresh());
  }
  final Ref ref;
  StreamSubscription<void>? _changes;
  Timer? _timer;
  VoidCallback? _release;
  bool _checking = false, _closed = false;
  Future<void> _refresh() async {
    if (_checking || _closed) return;
    _checking = true;
    try {
      final windows = await WindowController.getAll();
      final activeQueues = <String>{};
      for (final window in windows) {
        if (window.arguments.isEmpty || window.arguments.length > 4096)
          continue;
        try {
          final args = jsonDecode(window.arguments);
          if (args is Map &&
              args['type'] == 'player' &&
              args['session'] is String)
            activeQueues.add('player.window.queue:${args['session']}');
        } on FormatException {
          continue;
        }
      }
      final children = activeQueues.isNotEmpty;
      if (_closed) return;
      if (children) _release ??= ref.read(libraryProcessingProvider).hold();
      final db = ref.read(appDatabaseProvider);
      // These are temporary per-window queues. Shared playlists and the primary
      // queue have separate keys and are never cleared by window cleanup.
      final stale = await (db.select(
        db.appSettings,
      )..where((row) => row.key.like('player.window.queue:%'))).get();
      for (final row in stale) {
        if (!activeQueues.contains(row.key) &&
            row.updatedAt < DateTime.now().millisecondsSinceEpoch - 60000)
          await (db.delete(
            db.appSettings,
          )..where((value) => value.key.equals(row.key))).go();
      }
      if (children || _release != null)
        db.notifyUpdates({
          drift.TableUpdate.onTable(db.items),
          drift.TableUpdate.onTable(db.playbackProgress),
          drift.TableUpdate.onTable(db.readingProgress),
          drift.TableUpdate.onTable(db.notes),
          drift.TableUpdate.onTable(db.bookmarks),
          drift.TableUpdate.onTable(db.appSettings),
        });
      if (!children) {
        _release?.call();
        _release = null;
      }
    } catch (_) {
      /* A closing window can disappear during enumeration. */
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
    _changes?.cancel();
    _release?.call();
  }
}

final desktopPlayerCoordinatorProvider = Provider<DesktopPlayerCoordinator?>((
  ref,
) {
  if (!DesktopPlaybackWindows.available) return null;
  final coordinator = DesktopPlayerCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class DesktopPlaybackWindow extends ConsumerStatefulWidget {
  const DesktopPlaybackWindow({
    super.key,
    required this.itemId,
    this.position,
    this.fromQueue = false,
    this.title,
  });
  final String itemId;
  final double? position;
  final bool fromQueue;
  final String? title;
  @override
  ConsumerState<DesktopPlaybackWindow> createState() => _PlaybackWindowState();
}

class _PlaybackWindowState extends ConsumerState<DesktopPlaybackWindow> {
  Timer? _sharedChanges;
  @override
  void initState() {
    super.initState();
    unawaited(DesktopPlaybackWindows.installExitHandler());
    _sharedChanges = Timer.periodic(const Duration(seconds: 2), (_) {
      final db = ref.read(appDatabaseProvider);
      db.notifyUpdates({
        drift.TableUpdate.onTable(db.appSettings),
        drift.TableUpdate.onTable(db.notes),
        drift.TableUpdate.onTable(db.bookmarks),
        drift.TableUpdate.onTable(db.playbackProgress),
      });
    });
  }

  late final _router = GoRouter(
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Main library')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Manage this item in the main library window.'),
            FilledButton(
              onPressed: () => DesktopPlaybackWindows.showLibrary(),
              child: const Text('Show library window'),
            ),
            TextButton(
              onPressed: () =>
                  context.go('/player/${Uri.encodeComponent(widget.itemId)}'),
              child: const Text('Return to player'),
            ),
          ],
        ),
      ),
    ),
    initialLocation: Uri(
      path: '/player/${widget.itemId}',
      queryParameters: {
        if (widget.position != null) 'position': '${widget.position}',
        if (widget.fromQueue) 'queue': '1',
        if (widget.title != null) 'title': widget.title!,
      },
    ).toString(),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Tangerine · Playback window')),
          body: Center(
            child: FilledButton(
              onPressed: () =>
                  context.go('/player/${Uri.encodeComponent(widget.itemId)}'),
              child: const Text('Return to player'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/player/:id',
        builder: (_, s) => MediaPlayerScreen(
          key: ValueKey(s.uri.toString()),
          itemId: s.pathParameters['id']!,
          fromQueue: s.uri.queryParameters['queue'] == '1',
          initialPositionSeconds: double.tryParse(
            s.uri.queryParameters['position'] ?? '',
          ),
          multipartRepresentationId: s.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/details/:id',
        builder: (_, s) => MediaDetailsScreen(itemId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/playlists',
        builder: (_, s) =>
            PlaylistsScreen(currentItemId: s.uri.queryParameters['current']),
      ),
      GoRoute(
        path: '/player-settings',
        builder: (_, _) => const PlayerControlsScreen(),
      ),
    ],
  );
  @override
  void dispose() {
    _sharedChanges?.cancel();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Tangerine · Playback window',
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: _router,
  );
}
