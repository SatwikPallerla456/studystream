import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/playback/authenticated_media_relay.dart';

void main() {
  test(
    'protected ranges forward credentials and closing revokes the loopback endpoint',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <String>[];
      server.listen((request) async {
        requests.add(request.headers.value('authorization') ?? '');
        expect(request.headers.value('range'), 'bytes=1-3');
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set('content-range', 'bytes 1-3/5');
        request.response.contentLength = 3;
        request.response.add([2, 3, 4]);
        await request.response.close();
      });
      final relay = await AuthenticatedMediaRelay.start(
        Uri.parse('http://127.0.0.1:${server.port}/media'),
        {'Authorization': 'Bearer synthetic-secret'},
      );
      addTearDown(() async {
        client.close(force: true);
        await relay.close();
        await server.close(force: true);
      });
      expect(relay.uri.toString(), isNot(contains('synthetic-secret')));
      final request = await client.getUrl(relay.uri);
      request.headers.set('range', 'bytes=1-3');
      final response = await request.close();
      expect(response.statusCode, 206);
      expect(response.headers.value('content-range'), 'bytes 1-3/5');
      expect(
        await response.fold<List<int>>([], (all, part) => all..addAll(part)),
        [2, 3, 4],
      );
      expect(requests, ['Bearer synthetic-secret']);
      final denied = await (await client.getUrl(
        relay.uri.replace(path: '/other'),
      )).close();
      expect(denied.statusCode, 404);
      await denied.drain<void>();
      expect(requests.length, 1);
      await relay.close();
      final closedClient = HttpClient();
      addTearDown(() => closedClient.close(force: true));
      await expectLater(
        closedClient.getUrl(relay.uri),
        throwsA(isA<SocketException>()),
      );
    },
  );

  test(
    'upstream redirects never forward credentials to another server',
    () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      origin.listen((request) async {
        request.response.statusCode = 302;
        request.response.headers.set(
          'location',
          'http://example.invalid/steal',
        );
        await request.response.close();
      });
      final relay = await AuthenticatedMediaRelay.start(
        Uri.parse('http://127.0.0.1:${origin.port}/media'),
        {'Authorization': 'Bearer synthetic-secret'},
      );
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await relay.close();
        await origin.close(force: true);
      });
      final request = await client.getUrl(relay.uri);
      request.followRedirects = false;
      final response = await request.close();
      expect(response.statusCode, 302);
      expect(response.headers.value('location'), isNull);
      await response.drain<void>();
    },
  );
}
