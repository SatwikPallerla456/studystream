import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/utils/id_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/sync/lan_sync_client.dart';

/// Deliberate remote inputs and user-authored customization. Secrets live outside
/// AppDatabase so backups/sync cannot accidentally export account credentials.
class AdvancedPlayerRepository {
  AdvancedPlayerRepository(this.db);
  final AppDatabase db;
  static const groups = [
    'Transport',
    'Timeline',
    'Volume',
    'Tracks',
    'Queue',
    'Skip',
    'Shuffle',
    'Repeat',
    'Record',
    'Snapshot',
    'Mini-player',
    'Fullscreen',
  ];
  static const defaultOrder = [
    'Transport',
    'Timeline',
    'Volume',
    'Tracks',
    'Queue',
  ];
  static Uri streamUri(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !{'http', 'https', 'rtsp', 'rtp', 'udp', 'rtmp'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        raw.length > 4096 ||
        raw.contains(RegExp(r'[\x00-\x20]'))) {
      throw const FormatException(
        'Enter a network URL without embedded credentials (HTTP, HTTPS, RTSP, RTP, UDP or RTMP).',
      );
    }
    if (uri.hasQuery)
      throw const FormatException(
        'Signed/query URLs are session-only. Remove the query to save this stream.',
      );
    return uri;
  }

  static Uri openUri(String raw) {
    if (raw.length > 4096 || raw.contains(RegExp(r'[\x00-\x20]')))
      throw const FormatException(
        'Enter a URL of at most 4096 characters without spaces.',
      );
    final uri = Uri.tryParse(raw.trim());
    if (uri != null && uri.hasQuery) {
      if (uri.userInfo.isNotEmpty || uri.hasFragment)
        throw const FormatException(
          'Use a URL without embedded credentials or fragments.',
        );
      streamUri(
        Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
          path: uri.path,
        ).toString(),
      );
      return uri;
    }
    return streamUri(raw);
  }

  Future<List<Map<String, dynamic>>> list(String key) async {
    final value = jsonDecode(
      await db.getSetting('player.advanced.$key') ?? '[]',
    );
    return (value as List)
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }

  Future<void> saveList(String key, List<Map<String, dynamic>> rows) =>
      db.setSetting('player.advanced.$key', jsonEncode(rows));
  Future<void> saveStream(String name, String url) async {
    final uri = openUri(url);
    if (name.trim().isEmpty || name.length > 160)
      throw const FormatException(
        'Give the stream a name (up to 160 characters).',
      );
    final rows = await list('streams');
    final id = stableId('stream:$uri');
    rows.removeWhere((r) => r['id'] == id);
    if (rows.length >= 500)
      throw const FormatException(
        'Remove a saved stream before adding another (500 maximum).',
      );
    if (uri.hasQuery)
      await SecureCredentialStore(
        key: 'tangerine.stream.$id',
      ).write(uri.toString());
    rows.add({
      'id': id,
      'name': name.trim(),
      'url': uri.hasQuery
          ? Uri(
              scheme: uri.scheme,
              host: uri.host,
              port: uri.hasPort ? uri.port : null,
              path: uri.path,
            ).toString()
          : uri.toString(),
      'secure': uri.hasQuery,
    });
    await saveList('streams', rows);
  }

  Future<({List<Map<String, dynamic>> rows, int skipped})> previewStreams(
    File file,
  ) async {
    if (await file.length() > 16 * 1024 * 1024)
      throw const FormatException(
        'Choose a MyVLC library smaller than 16 MiB.',
      );
    final data = jsonDecode(await file.readAsString()) as Map;
    final items = data['items'] as List;
    if (items.length > 10000)
      throw const FormatException('The import limit is 10,000 entries.');
    final rows = <Map<String, dynamic>>[];
    var skipped = 0;
    for (final item in items.whereType<Map>()) {
      final raw = item['url'] as String? ?? '';
      if (raw.startsWith('file:')) continue;
      try {
        final uri = openUri(raw);
        rows.add({
          'url': uri.toString(),
          'name': (item['title'] as String? ?? uri.host).substring(
            0,
            (item['title'] as String? ?? uri.host).length.clamp(0, 160),
          ),
        });
      } on FormatException {
        skipped++;
      }
    }
    return (rows: rows, skipped: skipped);
  }

  Future<String> streamAddress(Map<String, dynamic> row) async {
    if (row['secure'] != true) return row['url'] as String;
    final value = await SecureCredentialStore(
      key: 'tangerine.stream.${row['id']}',
    ).read();
    if (value == null)
      throw const FormatException(
        'This stream needs its signed URL entered again after restore.',
      );
    return value;
  }

  Future<void> removeStream(Map<String, dynamic> row) async {
    await SecureCredentialStore(key: 'tangerine.stream.${row['id']}').clear();
    final rows = await list('streams');
    rows.removeWhere((r) => r['id'] == row['id']);
    await saveList('streams', rows);
  }

  Future<List<String>> order() async {
    try {
      final raw =
          jsonDecode(
                await db.getSetting('player.advanced.order') ??
                    jsonEncode(defaultOrder),
              )
              as List;
      final order = raw
          .whereType<String>()
          .where(groups.contains)
          .toSet()
          .toList();
      if (!order.contains('Transport')) order.insert(0, 'Transport');
      return order;
    } catch (_) {
      return List.of(defaultOrder);
    }
  }

  Future<void> saveOrder(List<String> order) async {
    final valid = order.where(groups.contains).toSet().toList();
    if (!valid.contains('Transport')) valid.insert(0, 'Transport');
    await db.setSetting('player.advanced.order', jsonEncode(valid));
  }

  static const skinKeys = {
    'chrome',
    'panel',
    'canvas',
    'track',
    'accent',
    'text',
    'muted',
    'divider',
  };
  static bool validSkin(Object? raw) =>
      raw is Map &&
      raw.isNotEmpty &&
      raw.keys.every(skinKeys.contains) &&
      raw.values.every(
        (v) => v is String && RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(v),
      );
  Future<Map<String, String>> skin() async {
    try {
      final raw = jsonDecode(
        await db.getSetting('player.advanced.skin') ?? '{}',
      );
      return validSkin(raw) ? Map<String, String>.from(raw as Map) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> importSkin(File file) async {
    if (await file.length() > 16384)
      throw const FormatException('Skin JSON must be smaller than 16 KiB.');
    final raw = jsonDecode(await file.readAsString());
    const keys = {
      'chrome',
      'panel',
      'canvas',
      'track',
      'accent',
      'text',
      'muted',
      'divider',
    };
    if (raw is! Map ||
        raw.isEmpty ||
        raw.keys.any((k) => !keys.contains(k)) ||
        raw.values.any(
          (v) => v is! String || !RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(v),
        ))
      throw const FormatException(
        'Choose a MyVLC JSON color skin: chrome, panel, canvas, track, accent, text, muted, divider with six-digit hex colors.',
      );
    await db.setSetting('player.advanced.skin', jsonEncode(raw));
  }

  Future<void> importAddon(File file) async {
    if (await file.length() > 256 * 1024)
      throw const FormatException('An add-on must be smaller than 256 KiB.');
    final source = await file.readAsString();
    final rows = await list('addons');
    if (rows.length >= 20)
      throw const FormatException('Remove an add-on first (20 maximum).');
    final id = stableId(source);
    if (rows.any((r) => r['id'] == id))
      throw const FormatException('This add-on is already imported.');
    rows.add({
      'id': id,
      'name': file.uri.pathSegments.last,
      'source': source,
      'enabled': false,
    });
    await saveList('addons', rows);
  }
}

class OnlineSubtitleService {
  OnlineSubtitleService();
  static const credentials = SecureCredentialStore(
    key: 'tangerine.opensubtitles',
  );
  Future<Map<String, dynamic>> account() async => Map<String, dynamic>.from(
    jsonDecode(await credentials.read() ?? '{}') as Map,
  );
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final auth = await account();
    final key = auth['key'] as String? ?? '';
    if (key.isEmpty)
      throw const FormatException('Save your OpenSubtitles API key first.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final uri = Uri.https('api.opensubtitles.com', '/api/v1/$path', query);
      final req = await client
          .openUrl(body == null ? 'GET' : 'POST', uri)
          .timeout(const Duration(seconds: 20));
      req.followRedirects = false;
      req.headers.set('Api-Key', key);
      req.headers.set('User-Agent', 'Tangerine v1.0');
      req.headers.set('Accept', 'application/json');
      if ((auth['token'] as String? ?? '').isNotEmpty)
        req.headers.set('Authorization', 'Bearer ${auth['token']}');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close().timeout(const Duration(seconds: 25));
      if (res.statusCode < 200 || res.statusCode >= 300)
        throw FormatException(
          'OpenSubtitles returned ${res.statusCode}. Check the API key/token, download quota or retry later.',
        );
      final bytes = await bounded(
        res,
        2 * 1024 * 1024,
      ).timeout(const Duration(seconds: 25));
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<int>> bounded(HttpClientResponse res, int limit) async {
    final bytes = <int>[];
    await for (final chunk in res.timeout(const Duration(seconds: 25))) {
      if (bytes.length + chunk.length > limit)
        throw const FormatException(
          'The server response exceeded the size limit.',
        );
      bytes.addAll(chunk);
    }
    return bytes;
  }

  Future<({List<Map<String, dynamic>> files, int pages})> search(
    String query,
    String language,
    int page,
  ) async {
    if (query.trim().isEmpty ||
        query.length > 256 ||
        !RegExp(r'^[a-z]{2,3}$').hasMatch(language))
      throw const FormatException(
        'Enter a title and a two/three-letter language code, such as en.',
      );
    final data = await request(
      'subtitles',
      query: {'query': query.trim(), 'languages': language, 'page': '$page'},
    );
    final rows = <Map<String, dynamic>>[];
    for (final entry in (data['data'] as List? ?? []).take(60)) {
      final attr = (entry as Map)['attributes'] as Map? ?? {};
      for (final file in (attr['files'] as List? ?? []).take(20)) {
        rows.add({
          'id': (file as Map)['file_id'],
          'name': file['file_name'] ?? attr['release'] ?? 'Subtitle',
          'language': attr['language'] ?? language,
          'downloads': attr['download_count'] ?? 0,
          'hearing': attr['hearing_impaired'] == true,
        });
      }
    }
    return (files: rows, pages: (data['total_pages'] as num? ?? 1).toInt());
  }

  Future<String> download(int id) async {
    final data = await request(
      'download',
      body: {'file_id': id, 'sub_format': 'srt'},
    );
    final uri = Uri.tryParse(data['link'] as String? ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !(uri.host == 'opensubtitles.com' ||
            uri.host.endsWith('.opensubtitles.com')))
      throw const FormatException(
        'The service returned an unsupported download host.',
      );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 20));
      req.followRedirects =
          false; // Never forward credentials to the download host.
      final res = await req.close().timeout(const Duration(seconds: 25));
      if (res.statusCode != 200)
        throw const FormatException(
          'Subtitle download failed. Search again for a fresh link.',
        );
      final bytes = await bounded(
        res,
        10 * 1024 * 1024,
      ).timeout(const Duration(seconds: 25));
      final text = utf8.decode(bytes);
      if (!RegExp(r'\d\d:\d\d:\d\d[,.]\d{3}\s*-->').hasMatch(text) ||
          text.contains('\u0000'))
        throw const FormatException(
          'The service did not return a valid UTF-8 SRT file.',
        );
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/Subtitles',
      );
      await dir.create(recursive: true);
      final file = File('${dir.path}/opensubtitles-$id.srt');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } finally {
      client.close(force: true);
    }
  }
}
