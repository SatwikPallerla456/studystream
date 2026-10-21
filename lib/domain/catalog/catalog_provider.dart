import 'dart:convert';
import 'dart:io';
import 'media_record_contract.dart';

abstract class CatalogProvider {
  String get id;
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int? year,
    String? type,
  });
}

/// User-supplied metadata is the first provider: offline, explicit selection,
/// no account, credential, licensing or automatic-match assumptions.
class JsonCatalogProvider implements CatalogProvider {
  JsonCatalogProvider(this.entries);
  final List<Map<String, dynamic>> entries;
  @override
  String get id => 'local-json';
  static Future<JsonCatalogProvider> fromFile(File file) async {
    if (await file.length() > 8 * 1024 * 1024) {
      throw const FormatException('Catalog file exceeds 8 MiB');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List || decoded.length > 10000) {
      throw const FormatException(
        'Catalog must contain an array of at most 10,000 records',
      );
    }
    final entries = <Map<String, dynamic>>[];
    final ids = <String>{};
    const keys = {
      'id',
      'title',
      'year',
      'synopsis',
      'credits',
      'genres',
      'rating',
      'ratingLabel',
      'show',
      'season',
      'episode',
      'episodeEnd',
      'edition',
      'type',
      'artist',
      'album',
      'author',
      'series',
      'track',
      'disc',
      'airDate',
      'extra',
      'extraType',
    };
    for (final row in decoded) {
      if (row is! Map || row['title'] is! String || row['id'] is! String) {
        throw const FormatException(
          'Each catalog record needs a string id and title',
        );
      }
      if ((row['id'] as String).isEmpty ||
          (row['id'] as String).length > 512 ||
          !ids.add(row['id'] as String) ||
          (row['title'] as String).trim().isEmpty) {
        throw const FormatException(
          'Catalog IDs must be unique and titles nonempty',
        );
      }
      final safe = <String, dynamic>{};
      for (final key in keys) {
        final value = row[key];
        if (value is String && value.length <= 16000 ||
            value is num && value.isFinite ||
            value is bool ||
            value == null) {
          safe[key] = value;
        }
      }
      for (final key in [
        'year',
        'season',
        'episode',
        'episodeEnd',
        'track',
        'disc',
      ]) {
        final value = safe[key];
        if (value != null &&
            (value is! int ||
                value < 0 ||
                value > (key == 'year' ? 9999 : 100000))) {
          throw FormatException('Invalid catalog $key');
        }
      }
      final rating = safe['rating'];
      if (rating != null && (rating is! num || rating < 0 || rating > 100)) {
        throw const FormatException('Invalid catalog rating');
      }
      final kind = safe['type'];
      if (kind != null &&
          !{'movie', 'episode', 'track', 'book', 'photo'}.contains(kind)) {
        throw const FormatException('Invalid catalog type');
      }
      MediaRecordContract.identity(safe['id'] as String);
      MediaRecordContract.validate(
        id: 'metadata:catalog-entry',
        kind: 'metadata',
        libraryId: 'local-json',
        itemId: 'catalog-entry',
        data: {
          for (final e in safe.entries)
            if (e.key != 'id' && e.key != 'type') e.key: e.value,
        },
      );
      entries.add(safe);
    }
    return JsonCatalogProvider(entries);
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s._/():\[\]{}-]+'), ' ').trim();

  @override
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int? year,
    String? type,
  }) async {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return [];
    final tokens = normalized.split(' ');
    final ranked = <({Map<String, dynamic> entry, int rank, String reason})>[];
    for (final entry in entries) {
      final exactId = entry['id'] == query;
      final title = _normalize(entry['title'] as String);
      final exactTitle = title == normalized;
      if (!exactId && !tokens.every((token) => title.contains(token))) continue;
      if (type != null &&
          entry['type'] != null &&
          entry['type'] != type &&
          !exactId)
        continue;
      final yearMatch = year != null && entry['year'] == year;
      // These are deterministic local sort weights, never confidence scores and
      // never a reason to apply a match without the user's selection.
      final rank =
          (exactId
              ? 1000
              : exactTitle
              ? 100
              : 10) +
          (yearMatch ? 5 : 0);
      final reason = [
        exactId
            ? 'Exact catalog ID'
            : exactTitle
            ? 'Exact title'
            : 'Title contains search words',
        if (yearMatch) 'year matches',
        if (year != null && !yearMatch)
          entry['year'] == null ? 'year unavailable' : 'different year',
        if (type != null && entry['type'] != null && entry['type'] != type)
          'different media type',
      ].join(' · ');
      ranked.add((entry: entry, rank: rank, reason: reason));
    }
    ranked.sort((a, b) {
      final order = b.rank.compareTo(a.rank);
      return order != 0
          ? order
          : (a.entry['id'] as String).compareTo(b.entry['id'] as String);
    });
    return [
      for (final hit in ranked.take(50))
        {...hit.entry, '_matchReason': hit.reason},
    ];
  }
}
