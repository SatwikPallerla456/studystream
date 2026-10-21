import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'catalog_provider.dart';
import 'catalog_online_policy.dart';

/// Device-local secret: never written to catalog snapshots, backups or sync.
abstract final class CatalogCredentials {
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _key = 'tangerine.metadata.tmdb.readToken';
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
    'api.tvmaze.com',
    'openlibrary.org',
    'musicbrainz.org',
  };

  static Future<Uint8List> bytes(
    Uri uri, {
    String? token,
    bool image = false,
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
      final request = await client.getUrl(uri);
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
      if (token != null && uri.host == 'api.themoviedb.org') {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close();
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || redirect == 4 || token != null) {
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
        throw const FormatException(
          'Provider access was refused. Check the TMDB token or try another provider.',
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
