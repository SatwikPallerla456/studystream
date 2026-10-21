import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Bounded local ID3v2 and FLAC Vorbis-comment reader. Unsupported containers
/// keep filename identification; tags never authorize identity reconciliation.
class EmbeddedAudioTags {
  static const maxBytes = 2 * 1024 * 1024;
  static Future<Map<String, dynamic>> read(File file) async {
    final handle = await file.open();
    try {
      final prefix = await handle.read(10);
      if (prefix.length < 10) return {};
      if (ascii.decode(prefix.take(3).toList(), allowInvalid: true) == 'ID3') {
        final version = prefix[3];
        if (!{3, 4}.contains(version) || prefix[5] & 0xC0 != 0) return {};
        int sync(List<int> value) =>
            value.fold<int>(0, (n, b) => (n << 7) | (b & 0x7f));
        final length = sync(prefix.sublist(6, 10));
        if (length > maxBytes) return {};
        final bytes = await handle.read(length);
        final data = ByteData.sublistView(bytes);
        final tags = <String, dynamic>{};
        var offset = 0;
        const names = {
          'TIT2': 'title',
          'TPE1': 'artist',
          'TALB': 'album',
          'TYER': 'year',
          'TDRC': 'year',
          'TRCK': 'track',
          'TPOS': 'disc',
        };
        while (offset + 10 <= bytes.length) {
          final id = ascii.decode(
            bytes.sublist(offset, offset + 4),
            allowInvalid: true,
          );
          if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(id)) break;
          final size = version == 4
              ? sync(bytes.sublist(offset + 4, offset + 8))
              : data.getUint32(offset + 4, Endian.big);
          if (size <= 0 || size > 16000 || offset + 10 + size > bytes.length)
            break;
          final flags = data.getUint16(offset + 8, Endian.big);
          final field = names[id];
          if (field != null && flags == 0)
            _put(
              tags,
              field,
              _text(bytes.sublist(offset + 10, offset + 10 + size)),
            );
          offset += 10 + size;
        }
        return tags;
      }
      if (ascii.decode(prefix.take(4).toList(), allowInvalid: true) == 'fLaC') {
        await handle.setPosition(4);
        var total = 0;
        while (total < maxBytes) {
          final header = await handle.read(4);
          if (header.length != 4) break;
          final length = (header[1] << 16) | (header[2] << 8) | header[3];
          total += length + 4;
          if (total > maxBytes) break;
          if (header[0] & 0x7f == 4) {
            final bytes = await handle.read(length), tags = <String, dynamic>{};
            final data = ByteData.sublistView(bytes);
            var offset = 0;
            int takeLength() {
              if (offset + 4 > bytes.length)
                throw const FormatException('Truncated tags');
              final n = data.getUint32(offset, Endian.little);
              offset += 4;
              return n;
            }

            final vendor = takeLength();
            offset += vendor;
            final count = takeLength();
            if (count > 1000) return {};
            const names = {
              'TITLE': 'title',
              'ARTIST': 'artist',
              'ALBUM': 'album',
              'DATE': 'year',
              'TRACKNUMBER': 'track',
              'DISCNUMBER': 'disc',
            };
            for (var i = 0; i < count; i++) {
              final n = takeLength();
              if (n > 16000 || offset + n > bytes.length) return {};
              final line = utf8.decode(
                bytes.sublist(offset, offset + n),
                allowMalformed: true,
              );
              offset += n;
              final split = line.indexOf('=');
              if (split < 1) continue;
              final field = names[line.substring(0, split).toUpperCase()];
              if (field != null) _put(tags, field, line.substring(split + 1));
            }
            return tags;
          }
          if (header[0] & 0x80 != 0) break;
          await handle.setPosition(await handle.position() + length);
        }
      }
      return {};
    } on FormatException {
      return {};
    } finally {
      await handle.close();
    }
  }

  static void _put(Map<String, dynamic> tags, String field, String raw) {
    final value = raw.replaceAll('\u0000', '').trim();
    if (value.isEmpty || value.length > 16000) return;
    if ({'year', 'track', 'disc'}.contains(field)) {
      final n = int.tryParse(RegExp(r'^\d+').firstMatch(value)?.group(0) ?? '');
      if (n != null && n >= 0 && n <= (field == 'year' ? 9999 : 100000))
        tags[field] = n;
    } else {
      tags[field] = value;
    }
  }

  static String _text(List<int> bytes) {
    if (bytes.isEmpty) return '';
    if (bytes[0] == 3)
      return utf8.decode(bytes.sublist(1), allowMalformed: true);
    if (bytes[0] == 0) return latin1.decode(bytes.sublist(1));
    var little = false, start = 1;
    if (bytes.length >= 3 && bytes[1] == 255 && bytes[2] == 254) {
      little = true;
      start = 3;
    } else if (bytes.length >= 3 && bytes[1] == 254 && bytes[2] == 255) {
      start = 3;
    }
    return String.fromCharCodes([
      for (var i = start; i + 1 < bytes.length; i += 2)
        little ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
    ]);
  }
}
