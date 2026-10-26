/// Tangerine's matching rules, independent of provider popularity or ordering.
abstract final class CatalogMatchPolicy {
  static String normalized(String value) => value.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );

  static bool exactTitle(String query, Map<String, dynamic> candidate) {
    final target = normalized(query);
    if (target.isEmpty) return false;
    return [
      candidate['title'],
      ...?candidate['_titles'] as List?,
    ].whereType<String>().any((title) => normalized(title) == target);
  }

  static List<String> queries(String query) {
    final original = query.trim();
    final words = original
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final tokens = words.split(' ');
    return {
      original,
      words,
      if (original.contains(':')) original.split(':').skip(1).join(':').trim(),
      if (tokens.length >= 4) tokens.skip(tokens.length - 3).join(' '),
    }.where((q) => q.length >= 3).take(3).toList();
  }

  static int score(String query, int? year, Map<String, dynamic> candidate) {
    final exact = exactTitle(query, candidate);
    final target = normalized(query),
        title = normalized('${candidate['title']}');
    return (exact
            ? 100
            : title.contains(target) || target.contains(title)
            ? 30
            : 0) +
        (year != null && candidate['year'] == year ? 20 : 0);
  }

  static Map<String, dynamic>? automatic(
    String query,
    int? year,
    List<Map<String, dynamic>> candidates,
  ) {
    if (year == null || candidates.any((c) => c['_searchTruncated'] == true))
      return null;
    final exact = candidates
        .where((c) => exactTitle(query, c) && c['year'] == year)
        .toList();
    return exact.length == 1 ? exact.single : null;
  }
}
