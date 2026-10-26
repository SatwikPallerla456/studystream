import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' show AppExitResponse;
import '../../data/music/music_session.dart';
import '../../data/providers/app_providers.dart';

final musicSessionProvider = NotifierProvider<MusicSessionOwner, MusicSession?>(
  MusicSessionOwner.new,
);

class MusicSessionOwner extends Notifier<MusicSession?>
    with WidgetsBindingObserver {
  Future<void> _pending = Future.value();
  MusicSession? _owned;
  Object? _remote;
  @override
  MusicSession? build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _owned?.dispose();
    });
    return null;
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _owned?.close();
    return AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState phase) {
    if (phase != AppLifecycleState.resumed)
      unawaited(_owned?.checkpoint().catchError((Object _) {}));
  }

  Future<void> _pauseOther() async {
    final remote = ref.read(remotePlaybackControllerProvider),
        status = ref.read(remotePlaybackControllerProvider).status;
    if (status['active'] == true &&
        status['backend'] != 'Continuous music · mpv') {
      try {
        await remote.execute(
          'pause',
          null,
          expectedItemId: status['itemId'] as String?,
        );
      } catch (_) {
        /* The previous player may have closed. */
      }
    }
  }

  void _attach(MusicSession session) {
    final remote = ref.read(remotePlaybackControllerProvider);
    remote.detach(_remote);
    _remote = remote.attach(
      status: () => {
        'active': session.track != null,
        'itemId': session.track?.item.id,
        'libraryId': session.track?.item.libraryId,
        'title': session.track?.title,
        'playing': session.player?.state.playing ?? false,
        'positionSeconds':
            (session.player?.state.position.inMilliseconds ?? 0) / 1000,
        'durationSeconds':
            (session.player?.state.duration.inMilliseconds ?? 0) / 1000,
        'volume': session.volume,
        'backend': 'Continuous music · mpv',
        'commands': [
          'play',
          'pause',
          'seek',
          'volume',
          'next',
          'previous',
          'stop',
          'mute',
        ],
      },
      perform: (action, value) async {
        switch (action) {
          case 'play':
            await session.play();
          case 'pause':
            await session.pause();
          case 'seek':
            await session.seek(Duration(milliseconds: (value! * 1000).round()));
          case 'volume':
            await session.setVolume(value!);
          case 'next':
            await session.skip(1);
          case 'previous':
            await session.skip(-1);
          case 'stop':
            await session.pause();
          case 'mute':
            await session.setVolume(
              session.volume == 0 ? session.profile.volume : 0,
            );
        }
      },
    );
  }

  Future<void> resume() async {
    final current = state;
    if (current == null) return;
    await _pauseOther();
    _attach(current);
    await current.play();
  }

  Future<void> start(String id, {bool fromQueue = false, bool radio = false}) {
    final operation = _pending.catchError((Object _) {}).then((_) async {
      await _pauseOther();
      if (state?.track?.item.id == id && !fromQueue) {
        _attach(state!);
        return;
      }
      final previous = state;
      state = null;
      _owned = null;
      await previous?.close();
      previous?.dispose();
      final session = MusicSession(
        ref.read(appDatabaseProvider),
        ref.read(lanSyncClientProvider),
        ref.read(playerLibraryRepositoryProvider),
      );
      _owned = session;
      state = session;
      try {
        await session.initialize(id, fromQueue: fromQueue, radio: radio);
        if (identical(_owned, session)) _attach(session);
      } catch (_) {
        state = null;
        _owned = null;
        await session.close();
        session.dispose();
        rethrow;
      }
    });
    _pending = operation;
    return operation;
  }

  Future<void> stop() async {
    final session = state;
    state = null;
    _owned = null;
    ref.read(remotePlaybackControllerProvider).detach(_remote);
    _remote = null;
    await session?.close();
    session?.dispose();
  }
}
