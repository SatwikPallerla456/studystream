import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Best-effort local subnet discovery; manual addresses remain available.
class LanDiscovery {
  static const port = 45832;
  RawDatagramSocket? _socket;

  Future<void> advertise(int httpPort, {String? name}) async {
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
      _socket = socket;
      socket.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          final packet = socket.receive();
          if (packet == null ||
              utf8.decode(packet.data, allowMalformed: true) !=
                  'StudyStream.discover.v1') {
            return;
          }
          socket.send(
            utf8.encode(
              jsonEncode({
                'service': 'StudyStream',
                'port': httpPort,
                'name': name ?? Platform.localHostname,
              }),
            ),
            packet.address,
            packet.port,
          );
        },
        onError: (Object _) {
          close();
        },
      );
    } on SocketException {
      /* Discovery is optional; HTTP and manual entry still work. */
    }
  }

  static Future<Map<Uri, String>> discover({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final hosts = <Uri, String>{};
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = socket.receive();
      if (packet == null || packet.data.length > 2048) return;
      try {
        final data =
            jsonDecode(utf8.decode(packet.data)) as Map<String, dynamic>;
        final value = data['port'];
        if (data['service'] != 'StudyStream' ||
            value is! int ||
            value < 1 ||
            value > 65535) {
          return;
        }
        hosts[Uri(scheme: 'http', host: packet.address.address, port: value)] =
            data['name'] as String? ?? 'Tangerine host';
      } on Object {
        /* Ignore unrelated datagrams. */
      }
    });
    try {
      final query = utf8.encode('StudyStream.discover.v1');
      socket.send(query, InternetAddress('255.255.255.255'), port);
      socket.send(query, InternetAddress.loopbackIPv4, port);
      await Future<void>.delayed(timeout);
    } finally {
      await subscription.cancel();
      socket.close();
    }
    return hosts;
  }

  void close() {
    _socket?.close();
    _socket = null;
  }
}
