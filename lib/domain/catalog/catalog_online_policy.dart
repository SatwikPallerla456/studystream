/// Public provider locations only; transport never carries credentials or paths.
abstract final class CatalogOnlinePolicy {
  static bool artwork(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (!_https(uri)) return false;
    return {
          'image.tmdb.org',
          'artworks.thetvdb.com',
          'static.tvmaze.com',
          'covers.openlibrary.org',
          'coverartarchive.org',
        }.contains(uri!.host) ||
        uri.host == 'archive.org' ||
        uri.host.endsWith('.archive.org');
  }

  static bool source(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return _https(uri) &&
        {
          'www.themoviedb.org',
          'thetvdb.com',
          'www.thetvdb.com',
          'www.tvmaze.com',
          'openlibrary.org',
          'musicbrainz.org',
          'coverartarchive.org',
        }.contains(uri!.host);
  }

  static bool _https(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      !uri.hasFragment &&
      uri.toString().length <= 2048;
}
