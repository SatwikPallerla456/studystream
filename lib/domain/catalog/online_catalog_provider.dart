import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'catalog_provider.dart';
import 'catalog_match_policy.dart';
import 'catalog_online_policy.dart';

/// Provider credentials stay outside catalog snapshots, backups and sync.
abstract final class CatalogCredentials {
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _key = 'tangerine.metadata.tmdb.readToken';
  static const _tvdbKey = 'tangerine.metadata.tvdb.apiKey';
  // Supplied by the release/run wrapper; project key is embedded in the binary.
  static const bundledTvdbKey = String.fromEnvironment('THETVDB_API_KEY');
  static bool get hasBundledTvdbKey => bundledTvdbKey.isNotEmpty;
  static Future<String?> readTvdb() async =>
      hasBundledTvdbKey ? bundledTvdbKey : await _storage.read(key: _tvdbKey);
  static Future<void> saveTvdb(String key) async {
    final value = key.trim();
    if (value.isEmpty) {
      await _storage.delete(key: _tvdbKey);
    } else {
      if (value.length > 4096 || value.contains(RegExp(r'\s'))) {
        throw const FormatException(
          'Enter the TheTVDB project API key without spaces.',
        );
      }
      await _storage.write(key: _tvdbKey, value: value);
    }
    TvdbCatalogSession.clear();
  }

  static Future<String?> read() => _storage.read(key: _key);
  static Future<void> save(String token) async {
    final value = token.trim();
    if (value.isEmpty) return _storage.delete(key: _key);
    if (value.length > 4096 || value.contains(RegExp(r'\s'))) {
      throw const FormatException(
        'Enter the TMDB API Read Access Token without spaces.',
      );
    }
    await _storage.write(key: _key, value: value);
  }
}

/// Interactive calls only. Bounded bodies, HTTPS allowlists, no automatic retry,
/// no credential-bearing redirects, and shared per-host pacing.
class CatalogHttp {
  static final _queues = <String, Future<void>>{};
  static final _last = <String, DateTime>{};
  static final _blockedUntil = <String, DateTime>{};
  static const apiHosts = {
    'api.themoviedb.org',
    'api4.thetvdb.com',
    'api.tvmaze.com',
    'openlibrary.org',
    'musicbrainz.org',
  };

  static Future<Uint8List> bytes(
    Uri uri, {
    String? token,
    bool image = false,
    Map<String, String>? postBody,
    int maxBytes = 2 * 1024 * 1024,
  }) {
    final host = uri.host;
    final result = (_queues[host] ?? Future<void>.value()).then((_) async {
      if (_blockedUntil[host]?.isAfter(DateTime.now()) ?? false) {
        throw const FormatException(
          'The provider asked us to wait. Retry in a minute.',
        );
      }
      final interval = {'openlibrary.org', 'musicbrainz.org'}.contains(host)
          ? 1050
          : 100;
      final wait =
          interval -
          DateTime.now()
              .difference(_last[host] ?? DateTime.fromMillisecondsSinceEpoch(0))
              .inMilliseconds;
      if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
      _last[host] = DateTime.now();
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        return await _request(
          client,
          uri,
          token: token,
          image: image,
          maxBytes: maxBytes,
          postBody: postBody,
        ).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        throw const FormatException('The provider timed out. Try again.');
      } on SocketException {
        throw const FormatException(
          'Cannot reach the provider. Check your connection and retry.',
        );
      } finally {
        client.close(force: true);
      }
    });
    _queues[host] = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  static Future<Uint8List> _request(
    HttpClient client,
    Uri uri, {
    String? token,
    required bool image,
    required int maxBytes,
    Map<String, String>? postBody,
  }) async {
    for (var redirect = 0; redirect <= 4; redirect++) {
      if (image
          ? !CatalogOnlinePolicy.artwork(uri.toString())
          : uri.scheme != 'https' ||
                !apiHosts.contains(uri.host) ||
                uri.userInfo.isNotEmpty ||
                (uri.hasPort && uri.port != 443)) {
        throw const FormatException(
          'The provider returned an unsupported address.',
        );
      }
      if (postBody != null &&
          (image ||
              uri.host != 'api4.thetvdb.com' ||
              uri.path != '/v4/login')) {
        throw const FormatException(
          'Unsupported provider authentication endpoint.',
        );
      }
      final request = await client.openUrl(
        postBody == null ? 'GET' : 'POST',
        uri,
      );
      request.followRedirects = false;
      request.persistentConnection = false;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Tangerine/1.0 (personal media catalog; interactive identification)',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        image ? 'image/*' : 'application/json',
      );
      if (token != null &&
          {'api.themoviedb.org', 'api4.thetvdb.com'}.contains(uri.host)) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (postBody != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(postBody));
      }
      final response = await request.close();
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null ||
            redirect == 4 ||
            token != null ||
            postBody != null) {
          throw const FormatException(
            'The provider returned an unsupported redirect.',
          );
        }
        var next = uri.resolve(location);
        // CAA's documented Location may use http. Upgrade a known artwork
        // host before validating; never make a plaintext network request.
        if (image &&
            next.scheme == 'http' &&
            !next.hasPort &&
            CatalogOnlinePolicy.artwork(
              next.replace(scheme: 'https').toString(),
            )) {
          next = next.replace(scheme: 'https');
        }
        uri = next;
        continue;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (uri.host == 'api4.thetvdb.com') TvdbCatalogSession.clear();
        throw const FormatException(
          'Provider access was refused. Check credentials in Provider setup, then retry.',
        );
      }
      if (response.statusCode == 429 || response.statusCode == 503) {
        final seconds =
            int.tryParse(response.headers.value('retry-after') ?? '') ?? 60;
        _blockedUntil[uri.host] = DateTime.now().add(
          Duration(seconds: seconds.clamp(1, 3600)),
        );
        throw const FormatException(
          'The provider is busy or rate limited. Wait a moment, then retry.',
        );
      }
      if (response.statusCode == 404) {
        throw const FormatException(
          'No provider details or artwork were found for this selection.',
        );
      }
      if (response.statusCode != 200) {
        throw const FormatException(
          'The provider could not complete the request. Try again later.',
        );
      }
      if (image &&
          !(response.headers.contentType?.mimeType.startsWith('image/') ??
              false)) {
        throw const FormatException('The artwork response was not an image.');
      }
      if (response.contentLength > maxBytes) {
        throw const FormatException(
          'The provider response exceeds the download limit.',
        );
      }
      final body = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (body.length + chunk.length > maxBytes) {
          throw const FormatException(
            'The provider response exceeds the download limit.',
          );
        }
        body.add(chunk);
      }
      return body.takeBytes();
    }
    throw const FormatException('Too many provider redirects.');
  }

  static Future<dynamic> json(
    String host,
    String path, [
    Map<String, String> query = const {},
    String? token,
  ]) async {
    try {
      return jsonDecode(
        utf8.decode(await bytes(Uri.https(host, path, query), token: token)),
      );
    } on FormatException catch (error) {
      if (error.source != null) {
        throw const FormatException(
          'The provider returned unreadable metadata.',
        );
      }
      rethrow;
    }
  }
}

String _text(dynamic value, [int limit = 15000]) {
  if (value is Map) value = value['value'];
  if (value is! String) return '';
  final plain = value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return plain.length > limit ? plain.substring(0, limit) : plain;
}

int? _year(dynamic value) {
  final year = value is String && value.length >= 4
      ? int.tryParse(value.substring(0, 4))
      : value is int
      ? value
      : null;
  return year != null && year >= 0 && year <= 9999 ? year : null;
}

String _joined(dynamic value) => value is List
    ? value
          .take(20)
          .map((v) => _text(v, 200))
          .where((v) => v.isNotEmpty)
          .join(', ')
    : '';
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<dynamic> _list(dynamic value) => value is List ? value : [];

class OnlineCatalogProvider implements CatalogProvider {
  OnlineCatalogProvider(this.id);
  @override
  final String id;
  static const labels = {
    'tvdb': 'TheTVDB',
    'tmdb': 'TMDB',
    'tvmaze': 'TVmaze',
    'open-library': 'Open Library',
    'musicbrainz': 'MusicBrainz',
  };
  static String label(String id) => labels[id] ?? 'Local JSON';
  static Map<String, dynamic> chooseRelease(
    Map<String, dynamic> candidate,
    Map<String, dynamic>? release,
  ) {
    final result = Map<String, dynamic>.from(candidate);
    final recording = candidate['_recordingId'];
    if (recording is! String || !_mbid(recording)) return result;
    result['id'] = recording;
    result.remove('album');
    result.remove('artworkUrl');
    if (release != null && _mbid('${release['id']}')) {
      result['id'] = 'recording/$recording/release/${release['id']}';
      result['album'] = _text(release['title'], 500);
      result['artworkUrl'] =
          'https://coverartarchive.org/release/${release['id']}/front-500';
    }
    return result;
  }

  static String attribution(String id) => switch (id) {
    'tvdb' =>
      'Metadata provided by TheTVDB. Please consider adding missing information or subscribing.',
    'tmdb' =>
      'This product uses the TMDB API but is not endorsed or certified by TMDB.',
    'tvmaze' => 'TVmaze · CC BY-SA. Provider data retains its source licence.',
    'musicbrainz' =>
      'MusicBrainz · core data CC0; supplementary data CC BY-SA. Cover Art Archive images retain their owners’ rights.',
    'open-library' =>
      'Open Library / Internet Archive. Covers retain their owners’ rights.',
    _ => 'User-supplied local catalog',
  };

  Map<String, dynamic> _candidate(Map<String, dynamic> data, int? year) => {
    ...data,
    '_providerId': id,
    '_matchReason':
        '${data['_matchReason']?.toString().isNotEmpty == true ? data['_matchReason'] : 'Provider search result'}${year == null
            ? ''
            : data['year'] == year
            ? ' · year matches'
            : ' · check year'}',
    'attribution': attribution(id),
  };

  Future<String> _token() async {
    final token = await CatalogCredentials.read();
    if (token == null || token.isEmpty) {
      throw const FormatException(
        'Add your TMDB API Read Access Token in Provider setup, then search again.',
      );
    }
    return token;
  }

  @override
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int? year,
    String? type,
  }) async {
    if (query.trim().isEmpty || query.length > 300) {
      throw const FormatException('Enter a title of at most 300 characters.');
    }
    if (year != null && (year < 1000 || year > 9999)) {
      throw const FormatException(
        'For online search, enter a year from 1000 to 9999 or leave it empty.',
      );
    }
    if (id == 'tvdb') {
      return TvdbCatalogSession.search(
        query,
        year: year,
        television: type == 'episode',
      );
    }
    if (id == 'tmdb') {
      final tv = type == 'episode';
      final data = _map(
        await CatalogHttp.json(
          'api.themoviedb.org',
          '/3/search/${tv ? 'tv' : 'movie'}',
          {
            'query': query,
            'include_adult': 'false',
            'language': 'en-US',
            'page': '1',
            if (year != null) 'year': '$year',
          },
          await _token(),
        ),
      );
      return [
        for (final raw in _list(data['results']).take(20))
          if (raw is Map &&
              raw['id'] is int &&
              _text(raw[tv ? 'name' : 'title']).isNotEmpty)
            _candidate(_tmdb(_map(raw), tv), year),
      ];
    }
    if (id == 'tvmaze') {
      final data = await CatalogHttp.json('api.tvmaze.com', '/search/shows', {
        'q': query,
      });
      return [
        for (final raw in _list(data).take(20))
          if (raw is Map &&
              raw['show'] is Map &&
              raw['show']['id'] is int &&
              _text(raw['show']['name']).isNotEmpty)
            _candidate(_tvmaze(_map(raw['show'])), year),
      ];
    }
    if (id == 'open-library') {
      final data = _map(
        await CatalogHttp.json('openlibrary.org', '/search.json', {
          'q': query,
          'limit': '20',
          'fields': 'key,title,author_name,first_publish_year,cover_i',
        }),
      );
      return [
        for (final raw in _list(data['docs']).take(20))
          if (raw is Map &&
              RegExp(r'^/works/OL[0-9]+W$').hasMatch('${raw['key']}'))
            _candidate({
              'id': raw['key'],
              'title': _text(raw['title'], 500),
              'author': _joined(raw['author_name']),
              'year': _year(raw['first_publish_year']),
              'type': 'book',
              'sourceUrl': 'https://openlibrary.org${raw['key']}',
              if (raw['cover_i'] is int && raw['cover_i'] > 0)
                'artworkUrl':
                    'https://covers.openlibrary.org/b/id/${raw['cover_i']}-L.jpg?default=false',
            }, year),
      ];
    }
    if (id == 'musicbrainz') {
      // Quote the input: user text must not become Lucene query operators.
      final escaped = query.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      final data = _map(
        await CatalogHttp.json('musicbrainz.org', '/ws/2/recording', {
          'query': 'recording:"$escaped"',
          'fmt': 'json',
          'limit': '20',
        }),
      );
      return [
        for (final raw in _list(data['recordings']).take(20))
          if (raw is Map &&
              _mbid('${raw['id']}') &&
              _text(raw['title']).isNotEmpty)
            _candidate(_recording(_map(raw)), year),
      ];
    }
    throw const FormatException('Choose a supported provider.');
  }

  Map<String, dynamic> _tmdb(Map<String, dynamic> row, bool tv) => {
    'id': '${tv ? 'tv' : 'movie'}/${row['id']}',
    'title': _text(row[tv ? 'name' : 'title'], 500),
    if (tv) 'show': _text(row['name'], 500),
    'year': _year(row[tv ? 'first_air_date' : 'release_date']),
    'synopsis': _text(row['overview']),
    'type': tv ? 'episode' : 'movie',
    'sourceUrl':
        'https://www.themoviedb.org/${tv ? 'tv' : 'movie'}/${row['id']}',
    if (row['poster_path'] is String &&
        RegExp(r'^/[a-zA-Z0-9._-]+$').hasMatch(row['poster_path']))
      'artworkUrl': 'https://image.tmdb.org/t/p/w500${row['poster_path']}',
  };
  Map<String, dynamic> _tvmaze(Map<String, dynamic> row) => {
    'id': 'show/${row['id']}',
    'title': _text(row['name'], 500),
    'show': _text(row['name'], 500),
    'year': _year(row['premiered']),
    'synopsis': _text(row['summary']),
    'genres': _joined(row['genres']),
    'type': 'episode',
    'sourceUrl': 'https://www.tvmaze.com/shows/${row['id']}',
    if (_map(row['image'])['medium'] is String &&
        CatalogOnlinePolicy.artwork(_map(row['image'])['medium']))
      'artworkUrl': row['image']['medium'],
  };
  static bool _mbid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(value);
  Map<String, dynamic> _recording(Map<String, dynamic> row) {
    final releases = _list(row['releases']).whereType<Map>().take(5).toList();
    final release = releases.isEmpty ? <dynamic, dynamic>{} : releases.first;
    final artists = _list(row['artist-credit'])
        .whereType<Map>()
        .map((a) => _text(a['name'] ?? _map(a['artist'])['name'], 200))
        .join(', ');
    return {
      'id': row['id'],
      'title': _text(row['title'], 500),
      'artist': artists,
      'album': _text(release['title'], 500),
      'year': _year(row['first-release-date'] ?? release['date']),
      'type': 'track',
      'sourceUrl': 'https://musicbrainz.org/recording/${row['id']}',
      '_releaseId': release['id'],
      '_matchReason': _text(row['disambiguation'], 500),
    };
  }

  /// Fetch details only for the previewed result. An episode match resolves an
  /// exact season/number; a show-level candidate never invents episode metadata.
  Future<Map<String, dynamic>> details(
    Map<String, dynamic> candidate, {
    int? season,
    int? episode,
    int? episodeEnd,
  }) async {
    if (id == 'tvdb') {
      return TvdbCatalogSession.details(
        candidate,
        season: season,
        episode: episode,
        episodeEnd: episodeEnd,
      );
    }
    var result = Map<String, dynamic>.from(candidate);
    final remote = candidate['id'] as String;
    if (id == 'tmdb') {
      if (!RegExp(r'^(movie|tv)/[0-9]+$').hasMatch(remote))
        throw const FormatException('Invalid TMDB identity.');
      final token = await _token(), tv = remote.startsWith('tv/');
      final row = _map(
        await CatalogHttp.json('api.themoviedb.org', '/3/$remote', {
          'language': 'en-US',
          'append_to_response': 'credits',
        }, token),
      );
      if ('${row['id']}' != remote.split('/').last ||
          _text(row[tv ? 'name' : 'title']).isEmpty) {
        throw const FormatException(
          'The provider returned incomplete title details. Retry this candidate.',
        );
      }
      result.addAll(_tmdb(row, tv));
      result['genres'] = _list(
        row['genres'],
      ).whereType<Map>().map((g) => _text(g['name'], 100)).join(', ');
      final cast = _list(
        _map(row['credits'])['cast'],
      ).whereType<Map>().take(10);
      result['credits'] = cast.map((c) => _text(c['name'], 200)).join(', ');
      if (tv && season != null && episode != null) {
        final ep = _map(
          await CatalogHttp.json(
            'api.themoviedb.org',
            '/3/$remote/season/$season/episode/$episode',
            {'language': 'en-US'},
            token,
          ),
        );
        if (ep['season_number'] != season ||
            ep['episode_number'] != episode ||
            _text(ep['name']).isEmpty) {
          throw const FormatException(
            'The provider did not return the requested episode. Check season and episode numbers.',
          );
        }
        result.addAll({
          'id':
              '$remote/season/$season/episode/$episode${episodeEnd != null && episodeEnd > episode ? '-$episodeEnd' : ''}',
          'title': _text(ep['name'], 500),
          'season': season,
          'episode': episode,
          if (episodeEnd != null) 'episodeEnd': episodeEnd,
          'year': _year(ep['air_date']),
          'airDate': _text(ep['air_date'], 10),
          'synopsis': _text(ep['overview']),
          'sourceUrl':
              'https://www.themoviedb.org/$remote/season/$season/episode/$episode',
        });
      }
    } else if (id == 'tvmaze' && season != null && episode != null) {
      final showId = remote.split('/').last;
      if (int.tryParse(showId) == null)
        throw const FormatException('Invalid TVmaze identity.');
      final ep = _map(
        await CatalogHttp.json(
          'api.tvmaze.com',
          '/shows/$showId/episodebynumber',
          {'season': '$season', 'number': '$episode'},
        ),
      );
      if (ep['season'] != season ||
          ep['number'] != episode ||
          ep['id'] is! int ||
          _text(ep['name']).isEmpty) {
        throw const FormatException(
          'The provider did not return the requested episode. Check season and episode numbers.',
        );
      }
      result.addAll({
        'id':
            'episode/${ep['id']}${episodeEnd != null && episodeEnd > episode ? '-$episodeEnd' : ''}',
        'title': _text(ep['name'], 500),
        'season': season,
        'episode': episode,
        if (episodeEnd != null) 'episodeEnd': episodeEnd,
        'year': _year(ep['airdate']),
        'airDate': _text(ep['airdate'], 10),
        'synopsis': _text(ep['summary']),
        'sourceUrl': 'https://www.tvmaze.com/episodes/${ep['id']}',
      });
    } else if (id == 'open-library') {
      if (!RegExp(r'^/works/OL[0-9]+W$').hasMatch(remote))
        throw const FormatException('Invalid Open Library identity.');
      final row = _map(
        await CatalogHttp.json('openlibrary.org', '$remote.json'),
      );
      if (row['key'] != remote)
        throw const FormatException(
          'The provider returned an unexpected book. Retry this candidate.',
        );
      result['synopsis'] = _text(row['description']);
      result['genres'] = _joined(row['subjects']);
    } else if (id == 'musicbrainz') {
      if (!_mbid(remote))
        throw const FormatException('Invalid MusicBrainz identity.');
      final row = _map(
        await CatalogHttp.json('musicbrainz.org', '/ws/2/recording/$remote', {
          'inc': 'artists+releases+genres+annotation',
          'fmt': 'json',
        }),
      );
      if (row['id'] != remote)
        throw const FormatException(
          'The provider returned an unexpected recording. Retry this candidate.',
        );
      result['synopsis'] = _text(row['annotation'] ?? row['disambiguation']);
      result['genres'] = _list(
        row['genres'],
      ).whereType<Map>().take(20).map((g) => _text(g['name'], 100)).join(', ');
      final releases = _list(row['releases'])
          .whereType<Map>()
          .where(
            (release) =>
                _mbid('${release['id']}') && _text(release['title']).isNotEmpty,
          )
          .take(20)
          .toList();
      result['_releaseOptions'] = [
        for (final release in releases)
          {
            'id': release['id'],
            'title': _text(release['title'], 500),
            'year': _year(release['date']),
            'country': _text(release['country'], 10),
          },
      ];
      // Album and cover are chosen together; do not silently present the first
      // arbitrary release as the user's edition of this recording.
      result.remove('artworkUrl');
      result.remove('album');
      result['_recordingId'] = remote;
      result['_detailNote'] =
          'Choose the release for album information and cover art, or keep recording-only details.';
    }
    // Shared-range details describe its first episode; boundaries remain user
    // hints, never synthesized timestamps or additional downloaded episodes.
    if (episodeEnd != null && episode != null && episodeEnd > episode) {
      result['_detailNote'] =
          'Description is for the first episode in this shared file.';
    }
    return result;
  }
}

/// Application authentication stays separate from persisted provider metadata.
/// Tokens live only in memory and are renewed before the documented month ends.
abstract final class TvdbCatalogSession {
  static String? _token;
  static DateTime? _expires;
  static Future<String>? _pending;
  static int _generation = 0;

  static void clear() {
    _generation++;
    _token = null;
    _expires = null;
    _pending = null;
  }

  static Future<String> token() async {
    if (_token != null && (_expires?.isAfter(DateTime.now()) ?? false))
      return _token!;
    if (_pending != null) return _pending!;
    final generation = _generation;
    final future = _login(generation);
    _pending = future;
    try {
      return await future;
    } finally {
      if (identical(_pending, future)) _pending = null;
    }
  }

  static Future<String> _login(int generation) async {
    final key = await CatalogCredentials.readTvdb();
    if (key == null || key.isEmpty) {
      throw const FormatException(
        'Add the TheTVDB project API key in Provider setup, then search again.',
      );
    }
    final response = _map(
      jsonDecode(
        utf8.decode(
          await CatalogHttp.bytes(
            Uri.https('api4.thetvdb.com', '/v4/login'),
            postBody: {'apikey': key},
          ),
        ),
      ),
    );
    final value = _map(response['data'])['token'];
    if (response['status'] != 'success' ||
        value is! String ||
        value.isEmpty ||
        value.length > 16000 ||
        value.contains(RegExp(r'\s'))) {
      throw const FormatException(
        'TheTVDB did not issue an access token. Check the project key.',
      );
    }
    if (generation != _generation)
      throw const FormatException(
        'Provider credentials changed. Search again.',
      );
    _token = value;
    _expires = DateTime.now().add(const Duration(days: 27));
    return value;
  }

  static Future<dynamic> _get(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    final response = _map(
      await CatalogHttp.json(
        'api4.thetvdb.com',
        '/v4$path',
        query,
        await token(),
      ),
    );
    if (response['status'] != 'success' || response['data'] == null) {
      throw const FormatException(
        'TheTVDB returned incomplete metadata. Try again later.',
      );
    }
    return response['data'];
  }

  static String? _artwork(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final uri = value.startsWith('https://')
        ? value
        : value.startsWith('banners/')
        ? 'https://artworks.thetvdb.com/$value'
        : null;
    return uri != null && CatalogOnlinePolicy.artwork(uri) ? uri : null;
  }

  static Map<String, dynamic> _record(
    Map<String, dynamic> row,
    String kind,
    String remote,
  ) {
    final english = _list(
      _map(row['translations'])['overviewTranslations'],
    ).whereType<Map>().where((v) => v['language'] == 'eng').firstOrNull;
    final synopsis =
        english?['overview'] ??
        _map(row['overviews'])['eng'] ??
        row['overview'];
    final image = _artwork(
      row['image'] ?? row['image_url'] ?? row['thumbnail'],
    );
    return {
      'id': '$kind/$remote',
      '_providerId': 'tvdb',
      'title': _text(row['name'] ?? row['title'], 500),
      'type': kind == 'series' ? 'episode' : 'movie',
      if (kind == 'series') 'show': _text(row['name'], 500),
      'year': _year(
        row['year'] ?? row['firstAired'] ?? _map(row['first_release'])['date'],
      ),
      'synopsis': _text(synopsis),
      'genres': _list(row['genres'])
          .take(20)
          .map((v) => _text(v is Map ? v['name'] : v, 100))
          .where((v) => v.isNotEmpty)
          .join(', '),
      if (image != null) 'artworkUrl': image,
      'sourceUrl': 'https://thetvdb.com/dereferrer/$kind/$remote',
      'attribution': OnlineCatalogProvider.attribution('tvdb'),
    };
  }

  static Future<List<Map<String, dynamic>>> search(
    String query, {
    int? year,
    required bool television,
  }) async {
    final kind = television ? 'series' : 'movie';
    final found = <String, Map<String, dynamic>>{};
    final queries = CatalogMatchPolicy.queries(query);
    if (queries.isEmpty) return [];
    var calls = 0;
    var truncated = false;
    // Try the original with year, then relaxed queries. Never match a shortened
    // fallback against itself: confidence always uses the original title/year.
    final requests = [
      (queries.first, year),
      if (year != null) (queries.first, null),
      for (final q in queries.skip(1)) (q, null),
    ];
    for (final request in requests) {
      if (++calls > 4) break;
      final rows = _list(
        await _get('/search', {
          'query': request.$1,
          'type': kind,
          'limit': '20',
          if (request.$2 != null) 'year': '${request.$2}',
        }),
      );
      if (rows.length >= 20) truncated = true;
      for (final row in rows.whereType<Map>().take(20)) {
        if (row['type'] != kind ||
            !RegExp(r'^[1-9][0-9]*$').hasMatch('${row['tvdb_id']}') ||
            _text(row['name']).isEmpty)
          continue;
        final candidate = _record(_map(row), kind, '${row['tvdb_id']}');
        candidate['_titles'] = [
          ..._list(row['aliases']).whereType<String>(),
          ..._map(row['translations']).values.whereType<String>(),
          if (row['name_translated'] is String) row['name_translated'],
        ].take(50).toList();
        final exact = CatalogMatchPolicy.exactTitle(query, candidate);
        candidate['_matchReason'] =
            '${exact ? 'Title matches' : 'Broader title result'}${year == null
                ? ''
                : candidate['year'] == year
                ? ' · year matches'
                : ' · check year'}';
        found[candidate['id'] as String] = candidate;
      }
      if (found.values.any(
        (c) =>
            CatalogMatchPolicy.exactTitle(query, c) &&
            (year == null || c['year'] == year),
      ))
        break;
    }
    for (final candidate in found.values)
      candidate['_searchTruncated'] = truncated;
    final result = found.values.toList()
      ..sort((a, b) {
        final score = CatalogMatchPolicy.score(
          query,
          year,
          b,
        ).compareTo(CatalogMatchPolicy.score(query, year, a));
        return score != 0 ? score : '${a['id']}'.compareTo('${b['id']}');
      });
    return result.take(20).toList();
  }

  /// Narrow adjacent-year sets only; never infer release compatibility from a
  /// premiere year or a broad/truncated search page.
  static Future<List<Map<String, dynamic>>?> adjacentMovieCandidates(
    String query,
    int year,
  ) async {
    final found = <String, Map<String, dynamic>>{};
    for (final adjacent in [year - 1, year + 1]) {
      if (adjacent < 1000 || adjacent > 9999) continue;
      final rows = _list(
        await _get('/search', {
          'query': query,
          'type': 'movie',
          'year': '$adjacent',
          'limit': '20',
        }),
      );
      if (rows.length >= 20) return null;
      for (final row in rows.whereType<Map>()) {
        if (row['type'] != 'movie' ||
            !RegExp(r'^[1-9][0-9]*$').hasMatch('${row['tvdb_id']}'))
          continue;
        final candidate = _record(_map(row), 'movie', '${row['tvdb_id']}');
        candidate['_titles'] = [
          ..._list(row['aliases']).whereType<String>(),
          ..._map(row['translations']).values.whereType<String>(),
        ];
        if (candidate['year'] == adjacent &&
            CatalogMatchPolicy.exactTitle(query, candidate))
          found[candidate['id'] as String] = candidate;
      }
    }
    // A crowded title is manual review, not an unbounded detail-fetch loop.
    return found.length <= 3 ? found.values.toList() : null;
  }

  static Future<Map<String, dynamic>> details(
    Map<String, dynamic> candidate, {
    int? season,
    int? episode,
    int? episodeEnd,
  }) async {
    final remote = '${candidate['id']}';
    final match = RegExp(r'^(movie|series)/([1-9][0-9]*)$').firstMatch(remote);
    if (match == null) throw const FormatException('Invalid TheTVDB identity.');
    final kind = match[1]!, number = match[2]!;
    final path = kind == 'movie' ? 'movies' : 'series';
    final row = _map(
      await _get('/$path/$number/extended', {'meta': 'translations'}),
    );
    if ('${row['id']}' != number || _text(row['name']).isEmpty) {
      throw const FormatException(
        'TheTVDB returned an unexpected title. Retry this selection.',
      );
    }
    final result = {...candidate, ..._record(row, kind, number)};
    if (kind == 'movie')
      result['_releaseYears'] = {
        for (final release in _list(row['releases']).whereType<Map>())
          if (_year(release['date']) != null) _year(release['date'])!,
        if (_year(_map(row['first_release'])['date']) != null)
          _year(_map(row['first_release'])['date'])!,
      }.toList();
    result['credits'] = _list(row['characters'])
        .whereType<Map>()
        .take(20)
        .map((c) => _text(c['personName'], 200))
        .where((v) => v.isNotEmpty)
        .toSet()
        .join(', ');
    if (kind == 'series' && (season != null || episode != null)) {
      if (season == null ||
          episode == null ||
          season < 0 ||
          episode < 0 ||
          (episodeEnd != null &&
              (episodeEnd < episode || episodeEnd - episode >= 32))) {
        throw const FormatException(
          'Supply a valid season and episode, with at most 32 episodes per file.',
        );
      }
      final data = _map(
        await _get('/series/$number/episodes/official', {
          'page': '0',
          'season': '$season',
          'episodeNumber': '$episode',
        }),
      );
      final ep = _list(data['episodes'])
          .whereType<Map>()
          .where(
            (v) =>
                v['seasonNumber'] == season &&
                v['number'] == episode &&
                '${v['seriesId']}' == number,
          )
          .firstOrNull;
      if (ep == null || ep['id'] is! int || _text(ep['name']).isEmpty) {
        throw const FormatException(
          'TheTVDB has no matching episode in official aired order. Check the season and episode.',
        );
      }
      result.addAll({
        'id':
            '$remote/official/$season/$episode${episodeEnd != null && episodeEnd > episode ? '-$episodeEnd' : ''}',
        'title': _text(ep['name'], 500),
        'season': season,
        'episode': episode,
        if (episodeEnd != null) 'episodeEnd': episodeEnd,
        'year': _year(ep['aired']),
        'airDate': _text(ep['aired'], 10),
        'synopsis': _text(ep['overview']),
        'sourceUrl': 'https://thetvdb.com/dereferrer/episode/${ep['id']}',
        '_detailNote':
            'Official aired episode order.${episodeEnd != null && episodeEnd > episode ? ' Description is for the first episode in this shared file.' : ''}',
      });
    }
    return result;
  }
}
