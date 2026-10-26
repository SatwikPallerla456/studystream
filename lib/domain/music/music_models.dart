import 'dart:convert';
import 'dart:math' as math;
import 'package:path/path.dart' as p;

class LyricLine {
  const LyricLine(this.milliseconds, this.text);
  final int milliseconds;
  final String text;
  static List<LyricLine> parse(String raw) {
    if (raw.length > 65536) throw const FormatException('Lyrics exceed 64 KiB');
    final rows = <LyricLine>[];
    var offset = 0;
    for (final line in const LineSplitter().convert(raw)) {
      final shift = RegExp(
        r'^\[offset:([+-]?\d+)\]',
        caseSensitive: false,
      ).firstMatch(line);
      if (shift != null) offset = int.parse(shift[1]!).clamp(-60000, 60000);
    }
    final time = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
    for (final line in const LineSplitter().convert(raw)) {
      final matches = time.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final text = line.substring(matches.last.end).trim();
      for (final match in matches) {
        final seconds = int.parse(match[2]!);
        if (seconds >= 60)
          throw const FormatException('Invalid lyric timestamp');
        final fraction = (match[3] ?? '').padRight(3, '0');
        rows.add(
          LyricLine(
            math.max(
              0,
              int.parse(match[1]!) * 60000 +
                  seconds * 1000 +
                  (int.tryParse(fraction) ?? 0) +
                  offset,
            ),
            text,
          ),
        );
        if (rows.length > 3000)
          throw const FormatException('Lyrics have over 3,000 lines');
      }
    }
    rows.sort((a, b) => a.milliseconds.compareTo(b.milliseconds));
    return rows;
  }
}

class CueTrack {
  const CueTrack(
    this.number,
    this.title,
    this.artist,
    this.startMs, {
    this.endMs,
  });
  final int number, startMs;
  final int? endMs;
  final String title, artist;
  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'artist': artist,
    'startMs': startMs,
    'endMs': endMs,
  };
  static List<CueTrack> decode(String raw) {
    final data = jsonDecode(raw);
    if (data is! List || data.length > 500)
      throw const FormatException('Invalid cue track list');
    final tracks = <CueTrack>[];
    for (final row in data) {
      if (row is! Map ||
          row.keys.any(
            (k) =>
                !{'number', 'title', 'artist', 'startMs', 'endMs'}.contains(k),
          ) ||
          row['number'] is! int ||
          row['number'] < 1 ||
          row['number'] > 999 ||
          row['startMs'] is! int ||
          row['startMs'] < 0 ||
          row['startMs'] > 315360000000 ||
          row['title'] is! String ||
          row['title'].length > 512 ||
          row['artist'] is! String ||
          row['artist'].length > 512 ||
          row['endMs'] != null &&
              (row['endMs'] is! int || row['endMs'] <= row['startMs']))
        throw const FormatException('Invalid cue track');
      if (tracks.isNotEmpty && row['startMs'] <= tracks.last.startMs)
        throw const FormatException('Cue times must increase');
      tracks.add(
        CueTrack(
          row['number'],
          row['title'],
          row['artist'],
          row['startMs'],
          endMs: row['endMs'],
        ),
      );
    }
    return tracks;
  }

  /// INDEX 01 is the audible track start. Pregaps (INDEX 00) stay part of the
  /// original recording; no guessed file identity or synthetic progress rows.
  static List<CueTrack> parse(String text, String filename) {
    if (text.length > 65536)
      throw const FormatException('Cue sheets exceed 64 KiB');
    String? file;
    var number = 0, title = '', artist = '', albumArtist = '';
    final rows = <CueTrack>[];
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      final f = RegExp(
        r'^FILE\s+"([^"]+)"\s+\S+$',
        caseSensitive: false,
      ).firstMatch(line);
      if (f != null) {
        final path = f[1]!;
        if (p.basename(path) != path ||
            path.contains('\\') ||
            path == '.' ||
            path == '..')
          throw const FormatException(
            'Cue files must name recordings in the same folder',
          );
        file = path;
        number = 0;
        continue;
      }
      final t = RegExp(
        r'^TRACK\s+(\d+)\s+AUDIO$',
        caseSensitive: false,
      ).firstMatch(line);
      if (t != null) {
        number = int.parse(t[1]!);
        title = 'Track $number';
        artist = albumArtist;
        continue;
      }
      final tag = RegExp(
        r'^(TITLE|PERFORMER)\s+"(.*)"$',
        caseSensitive: false,
      ).firstMatch(line);
      if (tag != null) {
        if (tag[2]!.length > 512)
          throw const FormatException('Cue label is too long');
        if (tag[1]!.toUpperCase() == 'TITLE' && number > 0) title = tag[2]!;
        if (tag[1]!.toUpperCase() == 'PERFORMER') {
          if (number == 0)
            albumArtist = tag[2]!;
          else
            artist = tag[2]!;
        }
      }
      final index = RegExp(
        r'^INDEX\s+01\s+(\d{1,4}):(\d{2}):(\d{2})$',
        caseSensitive: false,
      ).firstMatch(line);
      if (index != null && file == filename && number > 0) {
        final seconds = int.parse(index[2]!), frames = int.parse(index[3]!);
        if (seconds >= 60 || frames >= 75)
          throw const FormatException('Invalid cue time');
        rows.add(
          CueTrack(
            number,
            title,
            artist,
            int.parse(index[1]!) * 60000 +
                seconds * 1000 +
                (frames * 1000 / 75).round(),
          ),
        );
      }
    }
    if (rows.isEmpty)
      throw const FormatException(
        'This cue sheet has no tracks for the selected recording',
      );
    final bounded = [
      for (var i = 0; i < rows.length; i++)
        CueTrack(
          rows[i].number,
          rows[i].title,
          rows[i].artist,
          rows[i].startMs,
          endMs: i + 1 < rows.length ? rows[i + 1].startMs : null,
        ),
    ];
    return decode(jsonEncode(bounded.map((t) => t.toJson()).toList()));
  }
}

class MusicRules {
  const MusicRules({
    this.libraryId,
    this.artist = '',
    this.album = '',
    this.genre = '',
    this.tag = '',
    this.favorite = false,
    this.unplayed = false,
    this.minYear = 0,
    this.maxYear = 9999,
    this.minSeconds = 0,
    this.maxSeconds = 315360000,
    this.order = 'title',
    this.limit = 100,
  });
  final String? libraryId;
  final String artist, album, genre, tag, order;
  final bool favorite, unplayed;
  final int minYear, maxYear, minSeconds, maxSeconds, limit;
  Map<String, dynamic> toJson() => {
    'libraryId': libraryId,
    'artist': artist,
    'album': album,
    'genre': genre,
    'tag': tag,
    'favorite': favorite,
    'unplayed': unplayed,
    'minYear': minYear,
    'maxYear': maxYear,
    'minSeconds': minSeconds,
    'maxSeconds': maxSeconds,
    'order': order,
    'limit': limit,
  };
  factory MusicRules.fromJson(Map raw) {
    String text(String key) =>
        raw[key] is String ? (raw[key] as String).trim() : '';
    int integer(String key, int fallback) =>
        raw[key] is int ? raw[key] as int : fallback;
    final r = MusicRules(
      libraryId: raw['libraryId'] as String?,
      artist: text('artist'),
      album: text('album'),
      genre: text('genre'),
      tag: text('tag'),
      favorite: raw['favorite'] == true,
      unplayed: raw['unplayed'] == true,
      minYear: integer('minYear', 0),
      maxYear: integer('maxYear', 9999),
      minSeconds: integer('minSeconds', 0),
      maxSeconds: integer('maxSeconds', 315360000),
      order: text('order').isEmpty ? 'title' : text('order'),
      limit: integer('limit', 100),
    );
    if ([r.artist, r.album, r.genre, r.tag].any((v) => v.length > 512) ||
        r.minYear < 0 ||
        r.maxYear > 9999 ||
        r.minYear > r.maxYear ||
        r.minSeconds < 0 ||
        r.maxSeconds > 315360000 ||
        r.maxSeconds < r.minSeconds ||
        r.limit < 1 ||
        r.limit > 500 ||
        !{'title', 'recent', 'leastPlayed', 'random'}.contains(r.order))
      throw const FormatException('Invalid music playlist rules');
    return r;
  }
}

class AudioOutputProfile {
  const AudioOutputProfile({
    required this.id,
    required this.name,
    this.device = 'auto',
    this.deviceLabel = 'System default',
    this.volume = 70,
    this.preamp = 0,
    this.normalization = 'track',
    this.sampleRate = 48000,
  });
  final String id, name, device, deviceLabel, normalization;
  final double volume, preamp;
  final int sampleRate;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'device': device,
    'deviceLabel': deviceLabel,
    'volume': volume,
    'preamp': preamp,
    'normalization': normalization,
    'sampleRate': sampleRate,
  };
  factory AudioOutputProfile.fromJson(Map v) {
    final p = AudioOutputProfile(
      id: v['id'] as String,
      name: v['name'] as String,
      device: v['device'] as String? ?? 'auto',
      deviceLabel: v['deviceLabel'] as String? ?? 'System default',
      volume: (v['volume'] as num? ?? 70).toDouble(),
      preamp: (v['preamp'] as num? ?? 0).toDouble(),
      normalization: v['normalization'] as String? ?? 'track',
      sampleRate: v['sampleRate'] as int? ?? 48000,
    );
    if (p.name.isEmpty ||
        p.name.length > 100 ||
        p.device.length > 512 ||
        !p.volume.isFinite ||
        p.volume < 0 ||
        p.volume > 100 ||
        !p.preamp.isFinite ||
        p.preamp < -12 ||
        p.preamp > 12 ||
        !{'off', 'track', 'album', 'dynamic'}.contains(p.normalization) ||
        !{44100, 48000, 88200, 96000, 192000}.contains(p.sampleRate))
      throw const FormatException('Invalid audio output profile');
    return p;
  }
}
