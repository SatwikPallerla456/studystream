import 'dart:convert';
import 'dart:io';

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
      'artist',
      'album',
      'author',
      'series',
    };
    for (final row in decoded) {
      if (row is! Map || row['title'] is! String || row['id'] is! String) {
        throw const FormatException(
          'Each catalog record needs a string id and title',
        );
      }
      final safe = <String, dynamic>{};
      for (final key in keys) {
        final value = row[key];
        if (value is String && value.length <= 16000 ||
            value is num ||
            value == null) {
          safe[key] = value;
        }
      }
      entries.add(safe);
    }
    return JsonCatalogProvider(entries);
  }

  @override
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int? year,
    String? type,
  }) async => entries
      .where(
        (e) =>
            e['title'].toString().toLowerCase().contains(query.toLowerCase()) &&
            (year == null || e['year'] == year),
      )
      .take(50)
      .toList();
}
