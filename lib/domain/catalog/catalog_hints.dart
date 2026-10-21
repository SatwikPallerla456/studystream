import 'package:path/path.dart' as p;

/// Conservative local hints, never a provider match or a playback boundary.
/// A physical file retains one identity even when it names several episodes.
abstract final class CatalogHints {
  static const maxEpisodes = 32;
  static final _edition = RegExp(
    r'\{edition-([^{}\r\n]{1,128})\}|\[edition-([^\[\]\r\n]{1,128})\]',
    caseSensitive: false,
  );
  static const extraFolders = {
    'behind the scenes': 'behindScenes',
    'deleted scenes': 'deletedScene',
    'featurettes': 'featurette',
    'interviews': 'interview',
    'scenes': 'scene',
    'shorts': 'short',
    'trailers': 'trailer',
    'other': 'other',
  };

  /// Edition values preserve case: sidecars must name the same cut exactly.
  static String? edition(String name) {
    final match = _edition.firstMatch(name);
    final value = (match?[1] ?? match?[2])?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? extraKind(String relativePath) {
    final parts = p.posix.split(relativePath.replaceAll('\\', '/'));
    for (final folder in parts.reversed.skip(1)) {
      final kind = extraFolders[folder.toLowerCase()];
      if (kind != null) return kind;
    }
    // Explicit suffixes only; "Trailer Park Boys" remains a primary title.
    final suffix = RegExp(
      r'-(behindthescenes|deleted|featurette|interview|scene|short|trailer|other)$',
      caseSensitive: false,
    ).firstMatch(p.basenameWithoutExtension(relativePath));
    return switch (suffix?[1]?.toLowerCase()) {
      'behindthescenes' => 'behindScenes',
      'deleted' => 'deletedScene',
      'featurette' => 'featurette',
      'interview' => 'interview',
      'scene' => 'scene',
      'short' => 'short',
      'trailer' => 'trailer',
      'other' => 'other',
      _ => null,
    };
  }

  static String category(String itemType, Map<String, dynamic> hints) =>
      switch (itemType) {
        'video' =>
          hints['episode'] != null || hints['airDate'] != null
              ? 'television'
              : 'movies',
        'audio' => 'music',
        'epub' => 'books',
        'cbz' => 'comics',
        'pdf' || 'document' => 'documents',
        'image' => 'photos',
        _ => 'mixed',
      };

  static String? episodeLabel(Map<String, dynamic> metadata) {
    final season = metadata['season'],
        first = metadata['episode'],
        last = metadata['episodeEnd'];
    if (season is! int || first is! int) return null;
    final suffix = last is int && last > first && last - first < maxEpisodes
        ? '–$last'
        : '';
    return '${season == 0 ? 'Specials' : 'Season $season'} · Episode${suffix.isEmpty ? '' : 's'} $first$suffix';
  }

  /// Explicit publication numbering is a local browsing hint. Bare numeric
  /// suffixes are accepted only for comic archives, never arbitrary book names.
  static Map<String, dynamic> reading(String filename, {required bool comic}) {
    var name = p.basenameWithoutExtension(filename);
    name = name
        .replaceFirst(RegExp(r'\s*[\[(](?:19|20)\d{2}[\])].*$'), '')
        .trim();
    final explicit = RegExp(
      r'^(.*?)\s+(v(?:ol(?:ume)?)?\.?|c(?:h(?:apter)?)?\.?|#)\s*(\d{1,5}(?:\.\d{1,4})?)\b',
      caseSensitive: false,
    ).firstMatch(name);
    final bare = comic && explicit == null
        ? RegExp(r'^(.*?)\s+(\d{1,5}(?:\.\d{1,4})?)$').firstMatch(name)
        : null;
    final series = (explicit?[1] ?? bare?[1])?.trim();
    if (series == null ||
        series.isEmpty ||
        !RegExp(r'[a-zA-Z\u0080-\uffff]').hasMatch(series))
      return {};
    final value = num.tryParse(explicit?[3] ?? bare![2]!);
    if (value == null || !value.isFinite || value < 0 || value > 100000)
      return {};
    final volume = explicit?[2]?.toLowerCase().startsWith('v') ?? false;
    return {
      'series': series,
      if (volume && value is int) 'volume': value,
      if (!volume) 'chapter': value,
    };
  }

  static Map<String, dynamic> filename(String filename) {
    final raw = p.basenameWithoutExtension(filename);
    final explicitEdition = edition(raw);
    final explicit = RegExp(
      r'\{(tmdb|imdb|tvdb)[-:]([a-zA-Z0-9]+)\}',
      caseSensitive: false,
    ).firstMatch(raw);
    var stem = raw.replaceAll(_edition, '').replaceAll(RegExp(r'[._]'), ' ');
    final legacyEdition = RegExp(
      r"\b(extended(?: edition)?|director'?s? cut|theatrical|unrated|final cut)\b",
      caseSensitive: false,
    ).firstMatch(stem);
    final representationPattern = RegExp(
      r'\b(2160p|1080p|720p|4k|hdr10\+?|dolby vision|hevc|h264|h265|x264|x265|remastered)\b',
      caseSensitive: false,
    );
    final representations = representationPattern
        .allMatches(stem)
        .map((m) => m[0]!)
        .toList();
    final episode = RegExp(
      r'\bS(\d{1,2})E(\d{1,3})(-(?:S\d{1,2})?E?\d{1,3}|(?:E\d{1,3})*)\b|\b(\d{1,2})x(\d{1,3})(?:-(?:(\d{1,2})x)?(\d{1,3}))?\b',
      caseSensitive: false,
    ).firstMatch(stem);
    int? season, firstEpisode, endEpisode;
    String? rangeIssue;
    if (episode != null) {
      season = int.parse(episode[1] ?? episode[4]!);
      final startEpisode = int.parse(episode[2] ?? episode[5]!);
      firstEpisode = startEpisode;
      final suffix = episode[3] ?? '';
      if (suffix.startsWith('-')) {
        final range = RegExp(
          r'^-(?:S(\d{1,2}))?E?(\d{1,3})$',
          caseSensitive: false,
        ).firstMatch(suffix)!;
        if (range[1] != null && int.parse(range[1]!) != season) {
          rangeIssue = 'crossSeason';
        } else {
          endEpisode = int.parse(range[2]!);
        }
      } else if (suffix.isNotEmpty) {
        final values = RegExp(
          r'E(\d{1,3})',
          caseSensitive: false,
        ).allMatches(suffix).map((m) => int.parse(m[1]!)).toList();
        // Only contiguous entries form a range; do not invent missing episodes.
        if (values.asMap().entries.every(
          (e) => e.value == startEpisode + e.key + 1,
        )) {
          endEpisode = values.last;
        } else {
          rangeIssue = 'nonContiguous';
        }
      } else if (episode[7] != null) {
        if (episode[6] != null && int.parse(episode[6]!) != season) {
          rangeIssue = 'crossSeason';
        } else {
          endEpisode = int.parse(episode[7]!);
        }
      }
      if (endEpisode != null &&
          (endEpisode < startEpisode ||
              endEpisode - startEpisode + 1 > maxEpisodes)) {
        rangeIssue = 'invalidOrTooLarge';
        endEpisode = null;
      }
    }
    final dateMatch = RegExp(
      r'\b((?:19|20)\d{2})[- ](\d{2})[- ](\d{2})\b',
    ).firstMatch(stem);
    String? airDate;
    if (dateMatch != null) {
      final year = int.parse(dateMatch[1]!),
          month = int.parse(dateMatch[2]!),
          day = int.parse(dateMatch[3]!);
      final date = DateTime.utc(year, month, day);
      if (date.year == year && date.month == month && date.day == day) {
        airDate = '${dateMatch[1]}-${dateMatch[2]}-${dateMatch[3]}';
      }
    }
    final year = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(stem);
    final part = RegExp(
      r'\b(?:cd|disc|part)[ -]?(\d{1,3})\b',
      caseSensitive: false,
    ).firstMatch(stem);
    final idMarker = RegExp(
      r'\{(?:tmdb|imdb|tvdb)[-:][a-zA-Z0-9]+\}',
      caseSensitive: false,
    ).firstMatch(stem);
    final markers = [
      if (year != null && year.start > 0) year.start,
      if (episode != null) episode.start,
      if (airDate != null) dateMatch!.start,
      if (idMarker != null) idMarker.start,
      if (part != null && part.start > 0) part.start,
    ]..sort();
    var title = markers.isEmpty ? stem : stem.substring(0, markers.first);
    title = title.replaceAll(representationPattern, '');
    if (legacyEdition != null) title = title.replaceAll(legacyEdition[0]!, '');
    title = title.replaceFirst(
      RegExp(
        r'-(?:behindthescenes|deleted|featurette|interview|scene|short|trailer|other)$',
        caseSensitive: false,
      ),
      '',
    );
    title = title
        .replaceAll(RegExp(r'[\s(\[\-{]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final extra = extraKind(filename);
    return {
      'title': title,
      if (episode != null || airDate != null) 'show': title,
      'year': year == null || year.start == 0 ? null : int.parse(year[0]!),
      'season': season,
      'episode': firstEpisode,
      if (endEpisode != null && endEpisode != firstEpisode)
        'episodeEnd': endEpisode,
      if (rangeIssue != null) 'episodeRangeIssue': rangeIssue,
      'edition': explicitEdition ?? legacyEdition?[0],
      'representation': representations.join(' '),
      'airDate': airDate,
      'explicitProvider': explicit?[1]?.toLowerCase(),
      'explicitId': explicit?[2],
      'part': part?[1],
      'extra': extra != null,
      if (extra != null) 'extraType': extra,
      'matchState': 'unmatched',
      'source': 'filename',
    };
  }
}
