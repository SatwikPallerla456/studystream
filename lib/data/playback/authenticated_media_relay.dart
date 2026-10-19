import 'dart:async';
import 'dart:io';
import 'dart:math';

/// A short-lived, loopback-only range proxy for libVLC. Remote pairing secrets
/// stay in Dart and never become libVLC arguments or logged media URLs.
class AuthenticatedMediaRelay {
  AuthenticatedMediaRelay._(this._server, this._client, this.uri);

  final HttpServer _server;
  final HttpClient _client;
  final Uri uri;
  bool _closed = false;

  static Future<AuthenticatedMediaRelay> start(
    Uri source,
    Map<String, String> headers,
  ) async {
    if (!['http', 'https'].contains(source.scheme) ||
        source.userInfo.isNotEmpty) {
      throw const FormatException('Invalid remote media address.');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = HttpClient()..autoUncompress = false;
    final random = Random.secure();
    final token = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final uri = Uri.parse('http://127.0.0.1:${server.port}/$token');
    final relay = AuthenticatedMediaRelay._(server, client, uri);
    server.listen((request) async {
      try {
        if (request.uri.path != uri.path ||
            request.uri.hasQuery ||
            !['GET', 'HEAD'].contains(request.method)) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        final upstream = await client.openUrl(request.method, source);
        upstream.followRedirects =
            false; // Never forward credentials to a redirect.
        headers.forEach(upstream.headers.set);
        for (final name in ['range', 'if-range']) {
          final value = request.headers.value(name);
          if (value != null) upstream.headers.set(name, value);
        }
        final response = await upstream.close();
        request.response.statusCode = response.statusCode;
        for (final name in [
          'content-type',
          'content-length',
          'content-range',
          'accept-ranges',
          'etag',
          'last-modified',
        ]) {
          final value = response.headers.value(name);
          if (value != null) request.response.headers.set(name, value);
        }
        request.response.headers.set('cache-control', 'no-store');
        if (request.method == 'HEAD') {
          await response.drain<void>();
        } else {
          await request.response.addStream(response);
        }
        await request.response.close();
      } catch (_) {
        try {
          request.response.statusCode = HttpStatus.badGateway;
          await request.response.close();
        } catch (_) {
          /* The player may have cancelled a range during a seek. */
        }
      }
    });
    return relay;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _client.close(force: true);
    await _server.close(force: true);
  }
}
