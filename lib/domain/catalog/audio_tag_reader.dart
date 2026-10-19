import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Bounded ID3v2/ID3v1 and FLAC Vorbis tags. No artwork is decoded during scan.
class AudioTagReader {
  static Future<Map<String, dynamic>> read(String path) async {
    final file = await File(path).open();
    final tags = <String, dynamic>{};
    try {
      final length = await file.length();
      final header = await file.read(10);
      if (header.length < 10) return tags;
      if (ascii.decode(header.take(3).toList(), allowInvalid: true) == 'ID3') {
        final version = header[3];
        int synchsafe(List<int> b) => b.fold(0, (n, v) => (n << 7) | (v & 127));
        final size = synchsafe(header.sublist(6, 10));
        if ((version != 3 && version != 4) ||
            size > 16 * 1024 * 1024 ||
            header[5] & 0xc0 != 0) {
          return tags;
        }
        final bytes = await file.read(size);
        var at = 0;
        const fields = {
          'TIT2': 'title',
          'TPE1': 'artist',
          'TALB': 'album',
          'TRCK': 'track',
          'TPOS': 'disc',
          'TCON': 'genres',
          'TDRC': 'year',
          'TYER': 'year',
          'TCOM': 'author',
        };
        while (at + 10 <= bytes.length) {
          final id = ascii.decode(
            bytes.sublist(at, at + 4),
            allowInvalid: true,
          );
          final n = version == 4
              ? synchsafe(bytes.sublist(at + 4, at + 8))
              : ByteData.sublistView(bytes).getUint32(at + 4);
          if (n <= 0 || at + 10 + n > bytes.length) break;
          if (fields.containsKey(id) &&
              bytes[at + 8] == 0 &&
              bytes[at + 9] == 0) {
            final data = bytes.sublist(at + 10, at + 10 + n);
            String value = '';
            if (data.first == 0) value = latin1.decode(data.sublist(1));
            if (data.first == 3) {
              value = utf8.decode(data.sublist(1), allowMalformed: true);
            }
            if (data.first == 1 || data.first == 2) {
              var offset = 1;
              var little = false;
              if (data.length > 2 && data[1] == 255 && data[2] == 254) {
                little = true;
                offset = 3;
              } else if (data.length > 2 && data[1] == 254 && data[2] == 255) {
                offset = 3;
              }
              final units = <int>[];
              for (var i = offset; i + 1 < data.length; i += 2) {
                units.add(
                  little
                      ? data[i] | data[i + 1] << 8
                      : data[i] << 8 | data[i + 1],
                );
              }
              value = String.fromCharCodes(units);
            }
            tags[fields[id]!] = value.replaceAll('\u0000', '').trim();
          }
          at += 10 + n;
        }
      } else if (ascii.decode(header.take(4).toList(), allowInvalid: true) ==
          'fLaC') {
        await file.setPosition(4);
        var total = 0;
        while (true) {
          final h = await file.read(4);
          if (h.length < 4) break;
          final n = h[1] << 16 | h[2] << 8 | h[3];
          total += n;
          if (total > 16 * 1024 * 1024) break;
          if (h[0] & 127 == 4) {
            final bytes = await file.read(n), d = ByteData.sublistView(bytes);
            var at = 0;
            if (n < 8) break;
            final vendor = d.getUint32(at, Endian.little);
            at += 4 + vendor;
            if (at + 4 > n) break;
            final count = d.getUint32(at, Endian.little);
            at += 4;
            for (var i = 0; i < count && i < 10000 && at + 4 <= n; i++) {
              final len = d.getUint32(at, Endian.little);
              at += 4;
              if (at + len > n) break;
              final value = utf8.decode(
                bytes.sublist(at, at + len),
                allowMalformed: true,
              );
              at += len;
              final eq = value.indexOf('=');
              if (eq < 0) continue;
              const keys = {
                'TITLE': 'title',
                'ARTIST': 'artist',
                'ALBUM': 'album',
                'TRACKNUMBER': 'track',
                'DISCNUMBER': 'disc',
                'GENRE': 'genres',
                'DATE': 'year',
                'COMPOSER': 'author',
              };
              final key = keys[value.substring(0, eq).toUpperCase()];
              if (key != null) tags[key] = value.substring(eq + 1);
            }
          } else {
            await file.setPosition(await file.position() + n);
          }
          if (h[0] & 128 != 0) break;
        }
      }
      if (tags.isEmpty && length >= 128) {
        await file.setPosition(length - 128);
        final bytes = await file.read(128);
        if (ascii.decode(bytes.take(3).toList(), allowInvalid: true) == 'TAG') {
          String text(int a, int b) => latin1
              .decode(bytes.sublist(a, b))
              .replaceAll('\u0000', '')
              .trim();
          tags.addAll({
            'title': text(3, 33),
            'artist': text(33, 63),
            'album': text(63, 93),
            'year': text(93, 97),
          });
        }
      }
      return tags;
    } finally {
      await file.close();
    }
  }
}
