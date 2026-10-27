import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../data/db/app_database.dart';

class VideoPlaybackProfile {
  const VideoPlaybackProfile({
    required this.id,
    required this.name,
    this.speed = 1,
    this.dialogue = false,
    this.normalize = false,
    this.outputDevice = '',
    this.subtitleSize = 24,
    this.subtitleColor = 0xffffffff,
    this.networkCache = 1000,
    this.softwareDecoder = false,
  });
  final String id, name, outputDevice;
  final double speed, subtitleSize;
  final bool dialogue, normalize;
  final int subtitleColor, networkCache;
  final bool softwareDecoder;
  VideoPlaybackProfile copyWith({
    String? id,
    String? name,
    bool? dialogue,
    bool? normalize,
    String? outputDevice,
    int? networkCache,
    bool? softwareDecoder,
    double? speed,
    double? subtitleSize,
    int? subtitleColor,
  }) => VideoPlaybackProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    speed: speed ?? this.speed,
    dialogue: dialogue ?? this.dialogue,
    normalize: normalize ?? this.normalize,
    outputDevice: outputDevice ?? this.outputDevice,
    subtitleSize: subtitleSize ?? this.subtitleSize,
    subtitleColor: subtitleColor ?? this.subtitleColor,
    networkCache: networkCache ?? this.networkCache,
    softwareDecoder: softwareDecoder ?? this.softwareDecoder,
  );
  static const builtins = [
    VideoPlaybackProfile(id: 'movies', name: 'Movies', normalize: true),
    VideoPlaybackProfile(
      id: 'lectures',
      name: 'Lectures',
      dialogue: true,
      speed: 1.15,
    ),
    VideoPlaybackProfile(id: 'music', name: 'Music'),
    VideoPlaybackProfile(
      id: 'accessibility',
      name: 'Accessibility',
      dialogue: true,
      normalize: true,
      speed: .9,
      subtitleSize: 32,
      subtitleColor: 0xffffe082,
    ),
  ];
  Map<String, String> get nativePreferences => {
    'normalize': '$normalize',
    'normalizeLevel': '2',
    'networkCache': '$networkCache',
    'buffering': 'Custom',
    if (softwareDecoder) 'hardware': 'none',
    'subtitleSize': '${subtitleSize.round()}',
    'subtitleUnits': 'Pixels',
    'subtitleColor': '${subtitleColor & 0xffffff}',
    'outputDevice': outputDevice,
  };
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'speed': speed,
    'dialogue': dialogue,
    'normalize': normalize,
    'outputDevice': outputDevice,
    'subtitleSize': subtitleSize,
    'subtitleColor': subtitleColor,
    'networkCache': networkCache,
    'softwareDecoder': softwareDecoder,
  };
  factory VideoPlaybackProfile.fromJson(Map json) {
    final value = VideoPlaybackProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      speed: (json['speed'] as num? ?? 1).toDouble(),
      dialogue: json['dialogue'] == true,
      normalize: json['normalize'] == true,
      outputDevice: json['outputDevice'] as String? ?? '',
      subtitleSize: (json['subtitleSize'] as num? ?? 24).toDouble(),
      subtitleColor: json['subtitleColor'] as int? ?? 0xffffffff,
      networkCache: json['networkCache'] as int? ?? 1000,
      softwareDecoder: json['softwareDecoder'] == true,
    );
    if (value.id.isEmpty ||
        value.id.length > 80 ||
        value.name.trim().isEmpty ||
        value.name.length > 80 ||
        !value.speed.isFinite ||
        value.speed < .25 ||
        value.speed > 3 ||
        !value.subtitleSize.isFinite ||
        value.subtitleSize < 12 ||
        value.subtitleSize > 60 ||
        value.outputDevice.length > 512 ||
        value.networkCache < 150 ||
        value.networkCache > 20000)
      throw const FormatException('Invalid playback profile');
    return value;
  }
}

class VideoTimelineEntry {
  VideoTimelineEntry({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.note = '',
    this.snapshot,
  });
  final String id, title, note;
  final int start;
  final int? end;
  final String? snapshot;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'start': start,
    'end': end,
    'note': note,
    'snapshot': snapshot,
  };
  factory VideoTimelineEntry.fromJson(Map json) {
    final entry = VideoTimelineEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      start: json['start'] as int,
      end: json['end'] as int?,
      note: json['note'] as String? ?? '',
      snapshot: json['snapshot'] as String?,
    );
    if (entry.start < 0 ||
        (entry.end != null && entry.end! <= entry.start) ||
        entry.title.length > 160 ||
        entry.note.length > 8000) {
      throw const FormatException('Invalid timeline marker or clip');
    }
    return entry;
  }
}

class VideoPlaybackWorkspace {
  VideoPlaybackWorkspace(this.database, this.itemId);
  final AppDatabase database;
  final String itemId;
  String get timelineKey => 'player.video.timeline.$itemId';
  Future<List<VideoPlaybackProfile>> profiles() async {
    final raw =
        jsonDecode(await database.getSetting('player.video.profiles') ?? '[]')
            as List;
    return [
      ...VideoPlaybackProfile.builtins,
      for (final value in raw.take(48))
        VideoPlaybackProfile.fromJson(value as Map),
    ];
  }

  Future<VideoPlaybackProfile?> activeProfile() async {
    final id = await database.getSetting('player.video.profile.$itemId');
    if (id == null) return null;
    try {
      for (final profile in await profiles()) {
        if (profile.id == id) return profile;
      }
    } catch (_) {
      /* Invalid optional presets must not prevent media playback. */
    }
    return null;
  }

  Future<void> saveProfile(VideoPlaybackProfile profile) async {
    final rows = (await profiles())
        .where(
          (p) =>
              !VideoPlaybackProfile.builtins.any((b) => b.id == p.id) &&
              p.id != profile.id,
        )
        .toList();
    if (rows.length >= 48)
      throw const FormatException('Remove a saved profile first (48 maximum).');
    rows.add(VideoPlaybackProfile.fromJson(profile.toJson()));
    await database.setSetting(
      'player.video.profiles',
      jsonEncode(rows.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> deleteProfile(String id) async {
    final rows = (await profiles()).where(
      (p) =>
          p.id != id && !VideoPlaybackProfile.builtins.any((b) => b.id == p.id),
    );
    await database.setSetting(
      'player.video.profiles',
      jsonEncode(rows.map((p) => p.toJson()).toList()),
    );
  }

  Future<List<VideoTimelineEntry>> timeline() async {
    final raw =
        jsonDecode(await database.getSetting(timelineKey) ?? '[]') as List;
    final rows = [
      for (final value in raw.take(300))
        VideoTimelineEntry.fromJson(value as Map),
    ];
    rows.sort((a, b) => a.start.compareTo(b.start));
    return rows;
  }

  Future<void> add({
    required String title,
    required int start,
    int? end,
    String note = '',
    String? snapshot,
  }) => database.transaction(() async {
    final rows = await timeline();
    if (rows.length >= 300)
      throw const FormatException(
        'Remove a marker or clip first (300 maximum).',
      );
    final entry = VideoTimelineEntry.fromJson(
      VideoTimelineEntry(
        id: const Uuid().v4(),
        title: title.trim().isEmpty ? 'Marker' : title.trim(),
        start: start,
        end: end,
        note: note,
        snapshot: snapshot,
      ).toJson(),
    );
    rows.add(entry);
    await database.setSetting(
      timelineKey,
      jsonEncode(rows.map((r) => r.toJson()).toList()),
    );
  });
  Future<void> remove(String id) => database.transaction(() async {
    final rows = (await timeline()).where((r) => r.id != id);
    await database.setSetting(
      timelineKey,
      jsonEncode(rows.map((r) => r.toJson()).toList()),
    );
  });
}
