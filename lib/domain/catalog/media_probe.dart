import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:media_kit/media_kit.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../data/db/app_database.dart';
import '../../data/reader/book_page_source.dart';

/// A separate, paused, local-file-only engine. Never shares the user's player.
abstract final class MediaProbe {
  static final _recent = <String, Future<Map<String, dynamic>>>{};
  static Future<Map<String, dynamic>> read(Item item) {
    if (item.fileSize == null || item.modifiedAt == null) return _read(item);
    final key =
        '${item.id}:${item.filePath}:${item.fingerprint}:${item.fileSize}:${item.modifiedAt}';
    if (_recent[key] case final Future<Map<String, dynamic>> cached)
      return cached;
    final work = _read(item);
    _recent[key] = work;
    while (_recent.length > 4) {
      _recent.remove(_recent.keys.first);
    }
    unawaited(
      work.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {
          _recent.remove(key);
        },
      ),
    );
    return work;
  }

  static Future<Map<String, dynamic>> _read(Item item) async {
    final container = item.filename.split('.').last.toLowerCase();
    if (item.itemType == 'image') {
      final file = File(item.filePath);
      if (await file.length() > 32 * 1024 * 1024)
        throw const FormatException('Image header exceeds analysis budget');
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        await file.readAsBytes(),
      );
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        return {
          'analysisState': 'complete',
          'container': container,
          'width': descriptor.width,
          'height': descriptor.height,
        };
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
    }
    if (item.itemType == 'pdf') {
      final document = await PdfDocument.openFile(item.filePath);
      try {
        final page = document.pages.firstOrNull;
        return {
          'analysisState': 'complete',
          'container': container,
          'pageCount': document.pages.length,
          if (page != null) 'width': page.width,
          if (page != null) 'height': page.height,
        };
      } finally {
        await document.dispose();
      }
    }
    if ({'epub', 'cbz'}.contains(item.itemType)) {
      final source = await ArchiveBookSource.open(
        item.filePath,
        epub: item.itemType == 'epub',
      );
      try {
        return {
          'analysisState': 'complete',
          'container': container,
          'pageCount': source.pageCount,
        };
      } finally {
        await source.dispose();
      }
    }
    MediaKit.ensureInitialized();
    final player = Player(
      configuration: const PlayerConfiguration(
        title: 'Tangerine library analysis',
        muted: true,
        vo: 'null',
        bufferSize: 2 * 1024 * 1024,
        protocolWhitelist: ['file'],
      ),
    );
    try {
      final native = player.platform;
      if (native is! NativePlayer)
        throw const FormatException('Native analysis unavailable');
      await native.waitForPlayerInitialization.timeout(
        const Duration(seconds: 8),
      );
      for (final entry in {
        'pause': 'yes',
        'vid': 'no',
        'aid': 'no',
        'sid': 'no',
        'ao': 'null',
        'sub-auto': 'no',
        'audio-file-auto': 'no',
        'cover-art-auto': 'no',
        'ytdl': 'no',
        'load-scripts': 'no',
        'ordered-chapters': 'no',
        'demuxer-max-bytes': '2097152',
        'demuxer-readahead-secs': '0',
      }.entries) {
        await native.setProperty(entry.key, entry.value);
      }
      await player
          .open(Media(File(item.filePath).uri.toString()), play: false)
          .timeout(const Duration(seconds: 8));
      final deadline = DateTime.now().add(const Duration(seconds: 6));
      var count = 0;
      while (DateTime.now().isBefore(deadline)) {
        count = int.tryParse(await native.getProperty('track-list/count')) ?? 0;
        if (count > 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      Future<num?> number(String key) async {
        final value = num.tryParse(await native.getProperty(key));
        return value != null && value.isFinite && value >= 0 ? value : null;
      }

      final streams = <Map<String, dynamic>>[];
      for (var i = 0; i < count.clamp(0, 128); i++) {
        final kind = await native.getProperty('track-list/$i/type');
        final row = <String, dynamic>{
          'id': int.tryParse(await native.getProperty('track-list/$i/id')) ?? i,
          'kind': kind == 'sub'
              ? 'subtitle'
              : {'audio', 'video'}.contains(kind)
              ? kind
              : 'unknown',
        };
        for (final entry in {'codec': 'codec', 'language': 'lang'}.entries) {
          final value = await native.getProperty(
            'track-list/$i/${entry.value}',
          );
          if (value.isNotEmpty) row[entry.key] = value;
        }
        for (final entry in {
          'width': 'demux-w',
          'height': 'demux-h',
          'channels': 'demux-channel-count',
          'sampleRate': 'demux-samplerate',
          'frameRate': 'demux-fps',
          'bitrate': 'demux-bitrate',
        }.entries) {
          final value = await number('track-list/$i/${entry.value}');
          if (value != null) row[entry.key] = value;
        }
        streams.add(row);
      }
      final chapters = <Map<String, dynamic>>[];
      final chapterCount = (await number('chapter-list/count'))?.toInt() ?? 0;
      for (var i = 0; i < chapterCount.clamp(0, 512); i++) {
        final start = await number('chapter-list/$i/time');
        if (start == null) continue;
        final title = await native.getProperty('chapter-list/$i/title');
        chapters.add({
          'startSeconds': start,
          'title': title.isEmpty
              ? 'Chapter ${i + 1}'
              : title
                    .replaceAll(RegExp(r'[\x00-\x1f]'), ' ')
                    .substring(0, title.length.clamp(0, 256)),
        });
      }
      final tags = <String, dynamic>{};
      for (final field in [
        'title',
        'artist',
        'album',
        'date',
        'track',
        'disc',
      ]) {
        final raw = (await native.getProperty('metadata/by-key/$field')).trim();
        if (raw.isEmpty ||
            raw.length > 512 ||
            raw.contains(RegExp(r'[\x00-\x1f]')))
          continue;
        if ({'date', 'track', 'disc'}.contains(field)) {
          final value = int.tryParse(
            field == 'date' ? raw.split('-').first : raw.split('/').first,
          );
          if (value != null && value >= 0 && value <= 100000)
            tags[field == 'date' ? 'year' : field] = value;
        } else {
          tags[field] = raw;
        }
      }
      return {
        'container': container,
        'analysisState': streams.isEmpty ? 'unsupported' : 'complete',
        'streams': streams,
        'chapters': chapters,
        'tags': tags,
        if (await number('duration') case final num duration)
          'durationSeconds': duration,
      };
    } finally {
      await player.dispose();
    }
  }
}
