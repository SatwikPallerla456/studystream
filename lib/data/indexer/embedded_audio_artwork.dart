import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// Offline, seek-based artwork extraction. Large audio payloads are never read.
/// Supports ordinary ID3v2.3/v2.4 APIC, FLAC PICTURE, MP4/M4A/M4B covr,
/// and Vorbis/Opus comment pictures. No linked picture is fetched.
abstract final class EmbeddedAudioArtwork {
  static const maxImage = 8 * 1024 * 1024;
  static const maxMetadata = 32 * 1024 * 1024;
  static Future<Uint8List?> read(File file) {
    final path = file.path;
    return Isolate.run(() => _read(File(path)));
  }

  static Future<Uint8List?> _read(File file) async {
    final handle = await file.open();
    try {
      final prefix = await handle.read(12), length = await handle.length();
      if (prefix.length < 10) return null;
      if (_ascii(prefix, 0, 3) == 'ID3')
        return await _id3(handle, prefix, length);
      if (_ascii(prefix, 0, 4) == 'fLaC') return await _flac(handle, length);
      if (_ascii(prefix, 0, 4) == 'OggS') return await _ogg(handle, length);
      if (_ascii(prefix, 4, 4) == 'ftyp') return await _mp4(handle, length);
      return null;
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    } on FileSystemException {
      return null;
    } finally {
      await handle.close();
    }
  }

  static String _ascii(List<int> bytes, int offset, int count) =>
      latin1.decode(bytes.sublist(offset, offset + count));
  static int _sync(List<int> bytes, int offset) {
    if (bytes.skip(offset).take(4).any((b) => b > 127))
      throw const FormatException('Invalid ID3 size');
    return bytes.skip(offset).take(4).fold(0, (n, b) => (n << 7) | b);
  }

  static Future<Uint8List?> _id3(
    RandomAccessFile file,
    Uint8List header,
    int fileLength,
  ) async {
    final version = header[3];
    // Unsynchronization and extended-header layouts require a separate decoder.
    if (!{3, 4}.contains(version) || header[5] & 0xc0 != 0) return null;
    final length = _sync(header, 6), end = 10 + length;
    if (length > maxMetadata || end > fileLength) return null;
    var offset = 10, frames = 0;
    Uint8List? fallback;
    while (offset + 10 <= end && frames++ < 4096) {
      await file.setPosition(offset);
      final head = await file.read(10);
      if (head.length != 10 ||
          !RegExp(r'^[A-Z0-9]{4}$').hasMatch(_ascii(head, 0, 4)))
        break;
      final size = version == 4
          ? _sync(head, 4)
          : ByteData.sublistView(head).getUint32(4);
      if (size <= 0 || offset + 10 + size > end) break;
      if (_ascii(head, 0, 4) == 'APIC' &&
          head[9] == 0 &&
          size <= maxImage + 4096) {
        final body = await file.read(size);
        if (body.length == size) {
          final encoding = body[0];
          var cursor = 1;
          while (cursor < body.length && cursor < 128 && body[cursor] != 0) {
            cursor++;
          }
          if (cursor + 2 < body.length &&
              body[cursor] == 0 &&
              _ascii(body, 1, cursor - 1) != '-->') {
            final type = body[cursor + 1];
            cursor += 2;
            if (encoding == 0 || encoding == 3) {
              while (cursor < body.length && body[cursor] != 0) {
                cursor++;
              }
              cursor++;
            } else if (encoding == 1 || encoding == 2) {
              while (cursor + 1 < body.length &&
                  (body[cursor] != 0 || body[cursor + 1] != 0)) {
                cursor += 2;
              }
              cursor += 2;
            } else {
              cursor = body.length;
            }
            if (cursor < body.length && body.length - cursor <= maxImage) {
              final image = Uint8List.fromList(body.sublist(cursor));
              if (_image(image)) {
                if (type == 3) return image;
                fallback ??= image;
              }
            }
          }
        }
      }
      offset += 10 + size;
    }
    return fallback;
  }

  static Future<Uint8List?> _flac(RandomAccessFile file, int fileLength) async {
    var offset = 4, total = 0, blocks = 0;
    Uint8List? fallback;
    while (offset + 4 <= fileLength && blocks++ < 4096) {
      await file.setPosition(offset);
      final header = await file.read(4);
      if (header.length != 4) break;
      final length = (header[1] << 16) | (header[2] << 8) | header[3];
      total += 4 + length;
      if (total > maxMetadata || offset + 4 + length > fileLength) break;
      if (header[0] & 0x7f == 6 && length <= maxImage + 65536) {
        final picture = _flacPicture(await file.read(length));
        if (picture != null) {
          if (picture.$2 == 3) return picture.$1;
          fallback ??= picture.$1;
        }
      }
      if (header[0] & 0x80 != 0) break;
      offset += 4 + length;
    }
    return fallback;
  }

  static (Uint8List, int)? _flacPicture(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var cursor = 0;
    int number() {
      if (cursor + 4 > bytes.length)
        throw const FormatException('Truncated picture');
      final n = data.getUint32(cursor);
      cursor += 4;
      return n;
    }

    try {
      final type = number(), mimeLength = number();
      if (mimeLength > 128 || cursor + mimeLength > bytes.length) return null;
      final mime = _ascii(bytes, cursor, mimeLength);
      cursor += mimeLength;
      final description = number();
      if (description > 65536 ||
          cursor + description > bytes.length ||
          mime == '-->')
        return null;
      cursor += description;
      final width = number(), height = number();
      number();
      number();
      if (width > 24000 || height > 24000 || width * height > 80000000)
        return null;
      final length = number();
      if (length < 1 || length > maxImage || cursor + length > bytes.length)
        return null;
      final image = Uint8List.fromList(bytes.sublist(cursor, cursor + length));
      return _image(image) ? (image, type) : null;
    } on FormatException {
      return null;
    }
  }

  static bool _image(Uint8List bytes) =>
      bytes.length > 12 &&
      (bytes[0] == 0xff && bytes[1] == 0xd8 ||
          _ascii(bytes, 1, 3) == 'PNG' ||
          _ascii(bytes, 0, 3) == 'GIF' ||
          _ascii(bytes, 0, 4) == 'RIFF' && _ascii(bytes, 8, 4) == 'WEBP');

  static Future<Uint8List?> _mp4(RandomAccessFile file, int length) async {
    var atoms = 0, readBytes = 0;
    Future<Uint8List?> visit(
      int start,
      int end,
      int depth, {
      bool cover = false,
    }) async {
      if (depth > 12) return null;
      var offset = start;
      while (offset + 8 <= end && atoms++ < 4096 && readBytes < maxMetadata) {
        await file.setPosition(offset);
        final header = await file.read(8);
        readBytes += header.length;
        if (header.length != 8) return null;
        final data = ByteData.sublistView(header), type = _ascii(header, 4, 4);
        var size = data.getUint32(0), head = 8;
        if (size == 1) {
          final extended = await file.read(8);
          readBytes += extended.length;
          if (extended.length != 8) return null;
          size = ByteData.sublistView(extended).getUint64(0);
          head = 16;
        } else if (size == 0) {
          size = end - offset;
        }
        if (size < head || offset + size > end) return null;
        if (cover &&
            type == 'data' &&
            size - head > 8 &&
            size - head <= maxImage + 8) {
          final body = await file.read(size - head);
          readBytes += body.length;
          if (body.length != size - head) return null;
          final kind = ByteData.sublistView(body).getUint32(0) & 0xffffff;
          if ({13, 14}.contains(kind)) {
            final image = Uint8List.fromList(body.sublist(8));
            if (_image(image)) return image;
          }
        } else if ({'moov', 'udta', 'meta', 'ilst', 'covr'}.contains(type)) {
          final image = await visit(
            offset + head + (type == 'meta' ? 4 : 0),
            offset + size,
            depth + 1,
            cover: type == 'covr',
          );
          if (image != null) return image;
        }
        offset +=
            size; // mdat/audio bytes are skipped by seeking, regardless of size.
      }
      return null;
    }

    return visit(0, length, 0);
  }

  static Future<Uint8List?> _ogg(RandomAccessFile file, int fileLength) async {
    var offset = 0, consumed = 0;
    int? serial;
    var packet = BytesBuilder(copy: false);
    for (var page = 0; page < 1024 && offset + 27 <= fileLength; page++) {
      await file.setPosition(offset);
      final header = await file.read(27);
      if (header.length != 27 ||
          _ascii(header, 0, 4) != 'OggS' ||
          header[4] != 0)
        break;
      final segments = await file.read(header[26]);
      if (segments.length != header[26]) break;
      final size = segments.fold<int>(0, (n, b) => n + b);
      consumed += 27 + segments.length + size;
      if (consumed > maxMetadata ||
          offset + 27 + segments.length + size > fileLength)
        break;
      final pageSerial = ByteData.sublistView(
        header,
      ).getUint32(14, Endian.little);
      serial ??= pageSerial;
      if (pageSerial == serial) {
        final body = await file.read(size);
        if (body.length != size) break;
        var cursor = 0;
        for (final segment in segments) {
          if (packet.length + segment > 16 * 1024 * 1024) return null;
          packet.add(Uint8List.sublistView(body, cursor, cursor + segment));
          cursor += segment;
          if (segment < 255) {
            final bytes = packet.takeBytes();
            packet = BytesBuilder(copy: false);
            final start = bytes.length >= 8 && _ascii(bytes, 0, 8) == 'OpusTags'
                ? 8
                : bytes.length >= 7 &&
                      bytes[0] == 3 &&
                      _ascii(bytes, 1, 6) == 'vorbis'
                ? 7
                : null;
            if (start != null) return _commentPicture(bytes, start);
            // Headers precede audio. Do not traverse the complete stream looking for art.
            if (bytes.isNotEmpty &&
                !(_ascii(
                      bytes,
                      0,
                      bytes.length.clamp(0, 8),
                    ).contains('OpusHead') ||
                    bytes.length >= 7 &&
                        bytes[0] == 1 &&
                        _ascii(bytes, 1, 6) == 'vorbis'))
              return null;
          }
        }
      }
      offset += 27 + segments.length + size;
    }
    return null;
  }

  static Uint8List? _commentPicture(Uint8List bytes, int cursor) {
    final data = ByteData.sublistView(bytes);
    int number() {
      if (cursor + 4 > bytes.length)
        throw const FormatException('Truncated comments');
      final n = data.getUint32(cursor, Endian.little);
      cursor += 4;
      return n;
    }

    try {
      final vendor = number();
      if (vendor > bytes.length - cursor) return null;
      cursor += vendor;
      final count = number();
      if (count > 4096) return null;
      Uint8List? fallback;
      for (var i = 0; i < count; i++) {
        final length = number();
        if (length > 12 * 1024 * 1024 || length > bytes.length - cursor)
          return null;
        final text = utf8.decode(
          Uint8List.sublistView(bytes, cursor, cursor + length),
          allowMalformed: true,
        );
        cursor += length;
        final equals = text.indexOf('=');
        if (equals < 0) continue;
        final key = text.substring(0, equals).toUpperCase();
        if (key == 'METADATA_BLOCK_PICTURE') {
          final picture = _flacPicture(
            base64.decode(text.substring(equals + 1)),
          );
          if (picture != null) {
            if (picture.$2 == 3) return picture.$1;
            fallback ??= picture.$1;
          }
        } else if (key == 'COVERART') {
          final image = base64.decode(text.substring(equals + 1));
          if (image.length <= maxImage && _image(image)) fallback ??= image;
        }
      }
      return fallback;
    } on FormatException {
      return null;
    }
  }
}
