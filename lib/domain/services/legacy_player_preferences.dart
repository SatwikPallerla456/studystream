import 'dart:convert';
import 'dart:io';
import '../../core/utils/id_utils.dart';
import 'player_behavior_preferences.dart';
import 'player_controls_repository.dart';

const portableEnginePreferenceFields = <Map<String, Object>>[
  {
    'key': 'fileCache',
    'title': 'Local file buffer (ms)',
    'category': 'Buffering',
    'type': 'slider',
    'min': 0,
    'max': 10000,
    'initial': '300',
  },
  {
    'key': 'networkCache',
    'title': 'Network buffer (ms)',
    'category': 'Buffering',
    'type': 'slider',
    'min': 0,
    'max': 20000,
    'initial': '1000',
  },
  {
    'key': 'audioLanguage',
    'title': 'Preferred audio language',
    'category': 'Tracks',
    'type': 'text',
    'initial': '',
  },
  {
    'key': 'subtitleLanguage',
    'title': 'Preferred subtitle language',
    'category': 'Tracks',
    'type': 'text',
    'initial': '',
  },
  {
    'key': 'encoding',
    'title': 'Subtitle encoding',
    'category': 'Tracks',
    'type': 'choice',
    'choices': ['', 'UTF-8', 'UTF-16', 'ISO-8859-1', 'Windows-1252'],
    'initial': '',
  },
];

abstract final class LegacyPlayerPreferences {
  static Map<String, dynamic> preview(
    Object? document, {
    required Set<String> engineKeys,
  }) {
    if (document is! Map && document is! List)
      throw const FormatException(
        'Choose an exported MyVLC preference/profile JSON.',
      );
    final root = document is Map
        ? document
        : <String, dynamic>{'profiles': document};
    Map<String, String> preferences(Object? value) {
      if (value is! Map) return {};
      final raw = value['values'] is Map ? value['values'] as Map : value;
      final allowed = {
        ...engineKeys,
        ...PlayerBehaviorPreferences.fields.keys,
        ...PlayerPicturePreferences.keys,
        'volumeStep',
        'skipVeryShort',
        'skipShort',
        'skipMedium',
        'skipLong',
        'singleClick',
        'doubleClick',
        'scroll',
        'horizontalScroll',
        'reverseScroll',
      };
      final result = <String, String>{};
      for (final entry in raw.entries) {
        if (entry.key is! String ||
            !allowed.contains(entry.key) ||
            entry.value is! String)
          continue;
        final text = entry.value as String;
        if (text.length > 512 || text.contains(RegExp(r'[\x00-\x1f]')))
          continue;
        result[entry.key as String] = text;
      }
      for (final entry in const {
        'skipVeryShort': 30,
        'skipShort': 120,
        'skipMedium': 600,
        'skipLong': 1800,
        'volumeStep': 25,
      }.entries) {
        if (!result.containsKey(entry.key)) continue;
        final n = double.tryParse(result[entry.key]!);
        if (n == null ||
            !n.isFinite ||
            n < 1 ||
            n > entry.value ||
            n != n.roundToDouble())
          throw const FormatException('Invalid shortcut skip/volume amount');
      }
      for (final key in ['singleClick', 'doubleClick'])
        if (result.containsKey(key) &&
            !{
              'Nothing',
              'Play / Pause',
              'Toggle fullscreen',
            }.contains(result[key]))
          throw const FormatException('Invalid mouse click setting');
      for (final key in ['scroll', 'horizontalScroll'])
        if (result.containsKey(key) &&
            !{'Nothing', 'Volume', 'Seek'}.contains(result[key]))
          throw const FormatException('Invalid scroll setting');
      if (result.containsKey('reverseScroll') &&
          !{'true', 'false'}.contains(result['reverseScroll']))
        throw const FormatException('Invalid reverse scroll setting');
      PlayerBehaviorPreferences.project(result);
      PlayerPicturePreferences.project(result);
      return result;
    }

    final current = preferences(
      root['playerPreferences'] ?? root['preferences'] ?? root,
    );
    final profiles = <Map<String, dynamic>>[];
    final rows = root['profiles'];
    if (rows != null && (rows is! List || rows.length > 100))
      throw const FormatException('Import at most 100 player profiles.');
    for (final row in rows as List? ?? []) {
      if (row is! Map ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          (row['name'] as String).length > 200)
        throw const FormatException('Invalid original player profile.');
      final native = preferences(row['preferences']);
      final sourceEqualizer = row['equalizer'];
      Map<String, dynamic>? effects;
      if (sourceEqualizer is Map) {
        final bands = sourceEqualizer['bands'];
        final preamp = sourceEqualizer['preamp'];
        if (bands is! List ||
            bands.length != 10 ||
            bands.any((v) => v is! num || !v.isFinite || v < -20 || v > 20) ||
            preamp is! num ||
            !preamp.isFinite ||
            preamp < -20 ||
            preamp > 20)
          throw const FormatException('Invalid profile equalizer.');
        effects = {
          'equalizer': sourceEqualizer['enabled'] == true,
          'bands': bands,
          'preamp': preamp,
          'picture': <String, Object?>{},
        };
      }
      final picture = PlayerPicturePreferences.project(native);
      if (picture.isNotEmpty) {
        effects ??= {
          'equalizer': false,
          'bands': List.filled(10, 0.0),
          'preamp': 0,
        };
        effects['picture'] = picture;
      }
      profiles.add({
        'id': 'legacy:${stableId('${row['id'] ?? row['name']}')}',
        'title': row['name'],
        'native': native,
        'controlsPatch': {
          for (final entry in const {
            'volumeStep': 'volumeStep',
            'skipShort': 'skipSeconds',
            'skipVeryShort': 'veryShortSkip',
            'skipMedium': 'mediumSkip',
            'skipLong': 'longSkip',
            'singleClick': 'singleClick',
            'doubleClick': 'doubleClick',
            'scroll': 'verticalScroll',
            'horizontalScroll': 'horizontalScroll',
            'reverseScroll': 'reverseScroll',
          }.entries)
            if (native.containsKey(entry.key))
              entry.value: _controls(native, null).toJson()[entry.value],
        },
        'speed': _speed(
          (row['preferences'] as Map?)?['values'] is Map
              ? ((row['preferences'] as Map)['values'] as Map)['speed']
              : null,
        ),
        'effects': effects,
      });
    }
    final bindings = root['shortcutBindings'];
    return {
      'preferences': current,
      'controls': _controls(current, bindings).toJson(),
      'profiles': profiles,
      'speed': _preferenceSpeed(
        root['playerPreferences'] ?? root['preferences'] ?? root,
      ),
      'local': _bindings(bindings, 'local'),
      'global': _bindings(bindings, 'global'),
    };
  }

  static String? _preferenceSpeed(Object? raw) {
    if (raw is! Map) return null;
    final values = raw['values'];
    return _speed(values is Map ? values['speed'] : raw['speed']);
  }

  static String? _speed(Object? value) {
    final n = value is String ? double.tryParse(value) : null;
    return n != null && n.isFinite && n >= .25 && n <= 4 ? '$n' : null;
  }

  static Map<String, String> _bindings(Object? raw, String field) => raw is Map
      ? {
          for (final entry in raw.entries)
            if (playerActionTitles.containsKey(entry.key) &&
                entry.value is Map &&
                (entry.value as Map)[field] is String)
              entry.key as String: (entry.value as Map)[field] as String,
        }
      : {};
  static int _amount(String? raw, int fallback) {
    final n = double.tryParse(raw ?? '');
    return n != null && n.isFinite ? n.round() : fallback;
  }

  static PlayerControls _controls(
    Map<String, String> native,
    Object? bindings,
  ) {
    String click(String key, String fallback) =>
        {
          'Nothing': 'none',
          'Play / Pause': 'playPause',
          'Toggle fullscreen': 'fullscreen',
          'Volume': 'volume',
          'Seek': 'seek',
        }[native[key]] ??
        fallback;
    return PlayerControls(
      volumeStep: _amount(native['volumeStep'], 5).clamp(1, 50),
      local: _bindings(bindings, 'local'),
      global: _bindings(bindings, 'global'),
      skipSeconds: _amount(native['skipShort'], 10).clamp(1, 120),
      veryShortSkip: _amount(native['skipVeryShort'], 3).clamp(1, 30),
      mediumSkip: _amount(native['skipMedium'], 60).clamp(1, 600),
      longSkip: _amount(native['skipLong'], 300).clamp(1, 1800),
      singleClick: click('singleClick', 'playPause'),
      doubleClick: click('doubleClick', 'fullscreen'),
      verticalScroll: click('scroll', 'volume'),
      horizontalScroll: click('horizontalScroll', 'seek'),
      reverseScroll: native['reverseScroll'] == 'true',
    );
  }

  static Future<Map<String, dynamic>> file(
    File file, {
    required Set<String> engineKeys,
  }) async {
    if (await file.length() > 2 * 1024 * 1024)
      throw const FormatException(
        'Preference/profile imports are limited to 2 MiB.',
      );
    return preview(
      jsonDecode(await file.readAsString()),
      engineKeys: engineKeys,
    );
  }
}
