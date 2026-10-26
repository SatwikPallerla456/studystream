import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show SingleActivator;

import '../../data/db/app_database.dart';

const playerShortcutDefaults = <String, String>{
  'playPause': 'Space',
  'seekBack': 'Left',
  'seekForward': 'Right',
  'mute': 'M',
  'next': 'N',
  'previous': 'P',
  'volumeUp': 'Up',
  'volumeDown': 'Down',
  'fullscreen': 'F',
  'miniPlayer': 'Control+M',
  'nextFrame': 'E',
  'stop': 'S',
  'escape': 'Escape',
  'position': 'T',
  'hideUI': 'I',
  'snapshot': 'Shift+S',
  'record': 'Shift+R',
  'nextChapter': 'Shift+N',
  'previousChapter': 'Shift+P',
};
const playerActionTitles = <String, String>{
  'playPause': 'Play / pause',
  'seekBack': 'Seek backward',
  'seekForward': 'Seek forward',
  'mute': 'Mute',
  'next': 'Next item',
  'previous': 'Previous item',
  'volumeUp': 'Volume up',
  'volumeDown': 'Volume down',
  'fullscreen': 'Fullscreen',
  'miniPlayer': 'Mini-player',
  'nextFrame': 'Next frame',
  'stop': 'Stop playback',
  'escape': 'Exit fullscreen / show controls',
  'position': 'Show playback time',
  'hideUI': 'Show / hide controls',
  'snapshot': 'Take snapshot',
  'record': 'Start / stop recording',
  'nextChapter': 'Next chapter',
  'previousChapter': 'Previous chapter',
};

class PlayerControls {
  PlayerControls({
    Map<String, String>? local,
    Map<String, String>? global,
    this.skipSeconds = 10,
    this.volumeStep = 5,
    this.veryShortSkip = 3,
    this.mediumSkip = 60,
    this.longSkip = 300,
    this.singleClick = 'playPause',
    this.doubleClick = 'fullscreen',
    this.verticalScroll = 'volume',
    this.horizontalScroll = 'seek',
    this.reverseScroll = false,
  }) : local = {...playerShortcutDefaults, ...?local},
       global = global ?? {};
  final Map<String, String> local, global;
  final int skipSeconds, volumeStep, veryShortSkip, mediumSkip, longSkip;
  final String singleClick, doubleClick, verticalScroll, horizontalScroll;
  final bool reverseScroll;
  Map<String, Object> toJson() => {
    'local': local,
    'global': global,
    'skipSeconds': skipSeconds,
    'volumeStep': volumeStep,
    'veryShortSkip': veryShortSkip,
    'mediumSkip': mediumSkip,
    'longSkip': longSkip,
    'singleClick': singleClick,
    'doubleClick': doubleClick,
    'verticalScroll': verticalScroll,
    'horizontalScroll': horizontalScroll,
    'reverseScroll': reverseScroll,
  };
  static PlayerControls fromJson(Map json) => PlayerControls(
    local: Map<String, String>.from(json['local'] as Map? ?? {}),
    global: Map<String, String>.from(json['global'] as Map? ?? {}),
    skipSeconds: (json['skipSeconds'] as int? ?? 10).clamp(1, 600),
    volumeStep: (json['volumeStep'] as int? ?? 5).clamp(1, 50),
    veryShortSkip: (json['veryShortSkip'] as int? ?? 3).clamp(1, 30),
    mediumSkip: (json['mediumSkip'] as int? ?? 60).clamp(1, 600),
    longSkip: (json['longSkip'] as int? ?? 300).clamp(1, 1800),
    singleClick: json['singleClick'] as String? ?? 'playPause',
    doubleClick: json['doubleClick'] as String? ?? 'fullscreen',
    verticalScroll: json['verticalScroll'] as String? ?? 'volume',
    horizontalScroll: json['horizontalScroll'] as String? ?? 'seek',
    reverseScroll: json['reverseScroll'] == true,
  );
  static SingleActivator? activator(String value) {
    if (value.trim().isEmpty) return null;
    final parts = value
        .toLowerCase()
        .split('+')
        .map(
          (s) =>
              const {
                'ctrl': 'control',
                'cmd': 'command',
                'option': 'alt',
                '⌘': 'command',
                '⌃': 'control',
                '⇧': 'shift',
                '⌥': 'alt',
              }[s.trim()] ??
              s.trim(),
        )
        .toList();
    final key = parts.removeLast();
    if (parts.toSet().length != parts.length ||
        parts.any(
          (part) => !['control', 'shift', 'alt', 'command'].contains(part),
        )) {
      throw const FormatException(
        'Use Control, Shift, Alt, or Command plus a supported key.',
      );
    }
    final keys = {
      'space': LogicalKeyboardKey.space,
      'left': LogicalKeyboardKey.arrowLeft,
      'right': LogicalKeyboardKey.arrowRight,
      'up': LogicalKeyboardKey.arrowUp,
      'down': LogicalKeyboardKey.arrowDown,
      'escape': LogicalKeyboardKey.escape,
      'return': LogicalKeyboardKey.enter,
      'tab': LogicalKeyboardKey.tab,
      for (var code = 97; code <= 122; code++)
        String.fromCharCode(code): LogicalKeyboardKey.findKeyByKeyId(code)!,
      for (var code = 48; code <= 57; code++)
        String.fromCharCode(code): LogicalKeyboardKey.findKeyByKeyId(code)!,
    };
    final logical = keys[key];
    if (logical == null) {
      throw const FormatException(
        'Choose a letter, digit, arrow, Space, Return, Tab, or Escape.',
      );
    }
    return SingleActivator(
      logical,
      control: parts.contains('control'),
      shift: parts.contains('shift'),
      alt: parts.contains('alt'),
      meta: parts.contains('command'),
    );
  }
}

class PlayerControlsRepository {
  const PlayerControlsRepository(this.database);
  final AppDatabase database;
  Future<PlayerControls> load() async {
    final value = await database.getSetting('player.controls.v1');
    return value == null
        ? PlayerControls()
        : PlayerControls.fromJson(jsonDecode(value) as Map);
  }

  Future<void> save(PlayerControls controls) async {
    if (controls.veryShortSkip < 1 ||
        controls.veryShortSkip > 30 ||
        controls.mediumSkip < 1 ||
        controls.mediumSkip > 600 ||
        controls.longSkip < 1 ||
        controls.longSkip > 1800)
      throw const FormatException('Invalid modified seek amount');
    if (!{'none', 'playPause', 'fullscreen'}.contains(controls.singleClick) ||
        !{'none', 'playPause', 'fullscreen'}.contains(controls.doubleClick) ||
        !{'none', 'volume', 'seek'}.contains(controls.verticalScroll) ||
        !{'none', 'volume', 'seek'}.contains(controls.horizontalScroll))
      throw const FormatException('Invalid mouse action');
    for (final bindings in [controls.local, controls.global]) {
      final seen = <String>{};
      for (final row in bindings.entries) {
        if (!playerActionTitles.containsKey(row.key)) {
          throw const FormatException('Unknown player action.');
        }
        final value = row.value.trim();
        if (value.isEmpty) continue;
        final key = PlayerControls.activator(value)!;
        final normalized =
            '${key.trigger.keyId}:${key.control}:${key.alt}:${key.meta}:${key.shift}';
        if (!seen.add(normalized)) {
          throw const FormatException('Each shortcut must be unique.');
        }
        if (identical(bindings, controls.global) &&
            !(key.control || key.alt || key.meta || key.shift)) {
          throw const FormatException('Global shortcuts need a modifier key.');
        }
      }
    }
    await database.setSetting(
      'player.controls.v1',
      jsonEncode(controls.toJson()),
    );
  }

  Future<Map<String, String>> nativePreferences() async {
    final value = await database.getSetting('player.native.preferences');
    return value == null
        ? {}
        : Map<String, String>.from(jsonDecode(value) as Map);
  }
}
