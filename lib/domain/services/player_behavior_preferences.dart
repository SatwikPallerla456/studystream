/// Application behavior is separate from VLC command-line option ownership.
abstract final class PlayerBehaviorPreferences {
  static const fields = <String, Map<String, Object>>{
    'repeat': {
      'title': 'Repeat for this window’s queue',
      'type': 'choice',
      'choices': ['off', 'all', 'one'],
      'initial': 'off',
    },
    'shuffle': {
      'title': 'Shuffle this window’s queue',
      'type': 'toggle',
      'initial': 'false',
    },
    'trayIcon': {
      'title': 'Show Tangerine in the menu bar / system tray',
      'type': 'toggle',
      'initial': 'false',
    },
    'startMinimized': {
      'title': 'Start hidden when the tray icon is enabled',
      'type': 'toggle',
      'initial': 'false',
    },
    'trackPopup': {
      'title': 'Show a track-change notification',
      'type': 'choice',
      'choices': ['Never', 'When minimized', 'Always'],
      'initial': 'Never',
    },
    'popupDuration': {
      'title': 'Track notification duration (seconds)',
      'type': 'slider',
      'min': 1,
      'max': 10,
      'initial': '3',
    },
    'playlistTree': {
      'title': 'Group playlist entries by folder',
      'type': 'toggle',
      'initial': 'false',
    },
    'embeddedVideo': {
      'title': 'Open playback inside the main window',
      'type': 'toggle',
      'initial': 'true',
    },
    'finished': {
      'title': 'When the final item finishes',
      'type': 'choice',
      'choices': ['Stop', 'Minimize', 'Quit'],
      'initial': 'Stop',
    },
    'snapshotFolder': {
      'title': 'Initial snapshot folder',
      'type': 'text',
      'initial': '',
    },
    'snapshotPrefix': {
      'title': 'Snapshot filename prefix',
      'type': 'text',
      'initial': 'Tangerine-',
    },
    'snapshotFormat': {
      'title': 'Snapshot format',
      'type': 'choice',
      'choices': ['png', 'jpg'],
      'initial': 'png',
    },
    'snapshotWidth': {
      'title': 'Snapshot width (0 = source)',
      'type': 'choice',
      'choices': ['0', '640', '1280', '1920'],
      'initial': '0',
    },
    'snapshotSequential': {
      'title': 'Number snapshots sequentially',
      'type': 'toggle',
      'initial': 'true',
    },
    'snapshotPreview': {
      'title': 'Preview saved snapshots',
      'type': 'toggle',
      'initial': 'true',
    },
    'startPlaying': {
      'title': 'Start playing after opening a file',
      'type': 'toggle',
      'initial': 'true',
    },
    'continue': {
      'title': 'Continue saved playback',
      'type': 'choice',
      'choices': ['Always', 'Ask', 'Never'],
      'initial': 'Always',
    },
    'stopEach': {
      'title': 'Stop after each item',
      'type': 'toggle',
      'initial': 'false',
    },
    'startFullscreen': {
      'title': 'Start video in fullscreen',
      'type': 'toggle',
      'initial': 'false',
    },
    'preventSleep': {
      'title': 'Keep the screen awake during playback',
      'type': 'toggle',
      'initial': 'true',
    },
    'rememberVolume': {
      'title': 'Remember the last playback volume',
      'type': 'toggle',
      'initial': 'true',
    },
    'startupVolume': {
      'title': 'Starting volume (%)',
      'type': 'slider',
      'min': 0,
      'max': 100,
      'initial': '75',
    },
    'compactStartup': {
      'title': 'Start video with controls hidden',
      'type': 'toggle',
      'initial': 'false',
    },
    'outputDevice': {
      'title': 'Preferred audio output ID (empty = system default)',
      'type': 'text',
      'initial': '',
    },
    'alwaysOnTop': {
      'title': 'Keep player window above other windows',
      'type': 'toggle',
      'initial': 'false',
    },
    'rememberWindow': {
      'title': 'Remember player window position and size',
      'type': 'toggle',
      'initial': 'true',
    },
    'decorations': {
      'title': 'Show window title',
      'type': 'toggle',
      'initial': 'true',
    },
    'pauseMinimized': {
      'title': 'Pause when minimized',
      'type': 'toggle',
      'initial': 'false',
    },
    'frontPlayback': {
      'title': 'Bring player forward when playback starts',
      'type': 'toggle',
      'initial': 'false',
    },
    'filenameTitle': {
      'title': 'Show filename in player window title',
      'type': 'toggle',
      'initial': 'true',
    },
    'resizeVideo': {
      'title': 'Resize player to video',
      'type': 'choice',
      'choices': ['Never', 'Always', 'On first video'],
      'initial': 'Never',
    },
    'fullscreenScreen': {
      'title': 'Fullscreen display',
      'type': 'choice',
      'choices': ['Current screen', 'Main screen'],
      'initial': 'Current screen',
    },
    'autoHide': {
      'title': 'Auto-hide playback controls',
      'type': 'choice',
      'choices': ['Never', 'In fullscreen only', 'Always'],
      'initial': 'In fullscreen only',
    },
    'hideAfter': {
      'title': 'Hide controls after seconds',
      'type': 'slider',
      'min': 1,
      'max': 10,
      'initial': '3',
    },
    'opacity': {
      'title': 'Player window opacity',
      'type': 'slider',
      'min': 0.1,
      'max': 1.0,
      'initial': '1',
    },
    'controlsOpacity': {
      'title': 'Playback controls opacity',
      'type': 'slider',
      'min': 0.1,
      'max': 1.0,
      'initial': '1',
    },
    'fullscreenControls': {
      'title': 'Show controls in fullscreen',
      'type': 'toggle',
      'initial': 'true',
    },
    'coverArt': {
      'title': 'Show artwork when playing audio',
      'type': 'toggle',
      'initial': 'true',
    },
    'saveHistory': {
      'title': 'Save playback activity and progress',
      'type': 'toggle',
      'initial': 'true',
    },
    'resume': {
      'title': 'Resume from the saved playback position',
      'type': 'toggle',
      'initial': 'true',
    },
    'historyExclusion': {
      'title': 'Exclude paths from saved activity (regular expression)',
      'type': 'text',
      'initial': '',
    },
  };
  static Map<String, String> project(Map values) {
    final result = <String, String>{};
    for (final entry in fields.entries) {
      final value = values[entry.key];
      if (value is! String) continue;
      final field = entry.value;
      if (value.length > 512 || value.contains(RegExp(r'[\x00-\x1f]')))
        throw const FormatException('Invalid player preference');
      if (field['type'] == 'toggle' && !{'true', 'false'}.contains(value))
        throw const FormatException('Invalid preference switch');
      if (field['type'] == 'choice' &&
          !(field['choices'] as List).contains(value))
        throw const FormatException('Invalid preference choice');
      if (field['type'] == 'slider') {
        final n = double.tryParse(value);
        if (n == null ||
            !n.isFinite ||
            n < (field['min'] as num) ||
            n > (field['max'] as num))
          throw const FormatException('Invalid preference value');
      }
      if (entry.key == 'snapshotPrefix' &&
          (value.length > 80 || value.contains(RegExp(r'[\\/:*?"<>|]'))))
        throw const FormatException(
          'Use a snapshot prefix without path or filename separators',
        );
      if (entry.key == 'historyExclusion' && value.isNotEmpty) RegExp(value);
      result[entry.key] = value;
    }
    return result;
  }
}

/// Bounded live picture/timing fields shared by profile migration and playback.
abstract final class PlayerPicturePreferences {
  static const ranges = <String, (double, double)>{
    'brightness': (0, 2),
    'contrast': (0, 2),
    'saturation': (0, 3),
    'gamma': (.01, 10),
    'hue': (-180, 180),
    'zoom': (0, 5),
    'audioDelay': (-60, 60),
    'subtitleDelay': (-60, 60),
  };
  static Set<String> get keys => {
    ...ranges.keys,
    'aspect',
    'crop',
    'deinterlace',
    'deinterlaceMode',
  };
  static Map<String, Object?> project(Map raw) {
    final result = <String, Object?>{};
    for (final entry in ranges.entries) {
      if (!raw.containsKey(entry.key)) continue;
      final value = raw[entry.key];
      final n = value is num ? value.toDouble() : double.tryParse('$value');
      if (n == null ||
          !n.isFinite ||
          n < entry.value.$1 ||
          n > entry.value.$2) {
        throw const FormatException('Invalid picture/timing preference');
      }
      result[entry.key] = n;
    }
    for (final key in ['aspect', 'crop']) {
      if (!raw.containsKey(key)) continue;
      final value = raw[key];
      if (value is! String || value.length > 32)
        throw const FormatException('Invalid framing ratio');
      if (value.isNotEmpty) {
        final fields = value.split(':');
        final w = double.tryParse(fields.first),
            h = fields.length == 2 ? double.tryParse(fields.last) : null;
        if (w == null ||
            h == null ||
            !w.isFinite ||
            !h.isFinite ||
            w <= 0 ||
            h <= 0 ||
            w > 1000 ||
            h > 1000)
          throw const FormatException('Invalid framing ratio');
      }
      result[key] = value;
    }
    if (raw.containsKey('deinterlaceMode')) {
      final value = raw['deinterlaceMode'];
      if (!{
        'off',
        'auto',
        'blend',
        'bob',
        'linear',
        'yadif',
        'yadif2x',
      }.contains(value))
        throw const FormatException('Invalid deinterlace mode');
      result['deinterlaceMode'] = value == 'auto' ? 'yadif' : value;
    }
    if (raw['deinterlace'] == 'off') result['deinterlaceMode'] = 'off';
    return result;
  }
}
