import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import 'desktop_playback_windows.dart';

/// One primary-engine owner for process-wide desktop UI resources.
class DesktopApplicationBehavior with TrayListener {
  DesktopApplicationBehavior(this.database) {
    trayManager.addListener(this);
    DesktopPlaybackWindows.appActionHandler = _handleWindowAction;
    _settings = database
        .select(database.appSettings)
        .watch()
        .map((rows) {
          return rows
                  .where((row) => row.key == 'player.native.preferences')
                  .firstOrNull
                  ?.value ??
              '{}';
        })
        .distinct()
        .listen((raw) {
          _pending = _pending
              .then((_) async {
                if (_closed) return;
                final prefs = Map<String, String>.from(jsonDecode(raw) as Map);
                await _configure(prefs);
              })
              .catchError((Object _) async {
                if (!_closed)
                  await database.setSetting(
                    'player.desktop.error',
                    'Desktop tray or notifications could not be configured. Check system permissions.',
                  );
              });
        });
  }
  final AppDatabase database;
  StreamSubscription<String>? _settings;
  Future<void> _pending = Future.value();
  bool _closed = false,
      _tray = false,
      _startupApplied = false,
      _notifierReady = false;
  Map<String, String> _preferences = {};
  LocalNotification? _notification;
  Timer? _popupTimer;

  Future<void> _configure(Map<String, String> prefs) async {
    _preferences = prefs;
    final enabled = prefs['trayIcon'] == 'true';
    if (enabled && !_tray) {
      try {
        await trayManager.setIcon(
          Platform.isWindows
              ? 'assets/brand/tangerine.ico'
              : 'assets/brand/tangerine.png',
          isTemplate: false,
        );
        if (!Platform.isLinux) await trayManager.setToolTip('Tangerine');
        await trayManager.setContextMenu(
          Menu(
            items: [
              MenuItem(key: 'show', label: 'Show Tangerine'),
              MenuItem.separator(),
              MenuItem(key: 'quit', label: 'Quit Tangerine'),
            ],
          ),
        );
        _tray = true;
      } catch (_) {
        await trayManager.destroy();
        rethrow;
      }
    } else if (!enabled && _tray) {
      await trayManager.destroy();
      _tray = false;
      await DesktopPlaybackWindows.showLibrary();
    }
    if (!_startupApplied) {
      _startupApplied = true;
      if (_tray && prefs['startMinimized'] == 'true') {
        final window = await WindowController.fromCurrentEngine();
        await window.hide();
      }
    }
    if (!_notifierReady && (prefs['trackPopup'] ?? 'Never') != 'Never') {
      await localNotifier.setup(
        appName: 'Tangerine',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _notifierReady = true;
    }
    await database.setSetting('player.desktop.error', '');
  }

  Future<dynamic> _handleWindowAction(MethodCall call) async {
    if (call.method == 'showWindow') {
      await const MethodChannel(
        'tangerine/playback',
      ).invokeMethod<void>('app.show');
      return true;
    }
    if (call.method == 'openPlayer') {
      await DesktopPlaybackWindows.openInPrimary(
        Map<String, dynamic>.from(call.arguments as Map),
        database,
      );
      return true;
    }
    if (call.method != 'trackChanged') throw MissingPluginException();
    final args = call.arguments as Map? ?? {};
    final policy = _preferences['trackPopup'] ?? 'Never';
    if (policy == 'Never' ||
        policy == 'When minimized' && args['minimized'] != true)
      return null;
    if (!_notifierReady) return null;
    final title = args['title'];
    if (title is! String || title.isEmpty || title.length > 500) return null;
    await _notification?.destroy();
    _popupTimer?.cancel();
    final notification = LocalNotification(
      identifier: 'tangerine-now-playing',
      title: 'Now playing',
      body: title,
      silent: true,
    );
    _notification = notification;
    notification.onClick = () =>
        unawaited(DesktopPlaybackWindows.showLibrary());
    await notification.show();
    _popupTimer = Timer(
      Duration(
        seconds:
            (double.tryParse(_preferences['popupDuration'] ?? '')?.round() ?? 3)
                .clamp(1, 10),
      ),
      () => unawaited(notification.close()),
    );
    return null;
  }

  @override
  void onTrayIconMouseDown() => unawaited(DesktopPlaybackWindows.showLibrary());
  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());
  @override
  void onTrayMenuItemClick(MenuItem item) {
    unawaited(
      _trayAction(item.key).catchError((Object _) async {
        if (!_closed)
          await database.setSetting(
            'player.desktop.error',
            'The tray action could not finish. Open Tangerine and retry.',
          );
      }),
    );
  }

  Future<void> _trayAction(String? action) async {
    if (action == 'show') await DesktopPlaybackWindows.showLibrary();
    if (action == 'quit') {
      await DesktopPlaybackWindows.prepareExit?.call();
      await DesktopPlaybackWindows.prepareOtherWindowsForExit();
      await const MethodChannel(
        'tangerine/playback',
      ).invokeMethod<void>('app.quit');
    }
  }

  void dispose() {
    _closed = true;
    _settings?.cancel();
    _popupTimer?.cancel();
    trayManager.removeListener(this);
    unawaited(
      _pending
          .then((_) async {
            await _notification?.destroy();
            if (_tray) await trayManager.destroy();
          })
          .catchError((Object _) {}),
    );
    DesktopPlaybackWindows.appActionHandler = null;
  }
}

final desktopApplicationBehaviorProvider =
    Provider<DesktopApplicationBehavior?>((ref) {
      if (!DesktopPlaybackWindows.available) return null;
      final owner = DesktopApplicationBehavior(ref.watch(appDatabaseProvider));
      ref.onDispose(owner.dispose);
      return owner;
    });
