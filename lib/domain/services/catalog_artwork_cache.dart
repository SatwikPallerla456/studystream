import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import '../../core/utils/id_utils.dart';
import '../catalog/catalog_online_policy.dart';
import '../catalog/online_catalog_provider.dart';
import '../reader/reader_jobs.dart' show ReaderLease;

/// Regenerable provider artwork. 100 MiB disk LRU, 2 MiB downloads, 600x900
/// decoded targets, 32 MP source ceiling, one decode at a time. Never overwrites
/// Items.thumbnailPath or a user's media. All hosted output is normalized PNG.
class CatalogArtworkCache {
  static final instance = CatalogArtworkCache();
  final _pending = <String, Future<String?>>{};
  final _failedUntil = <String, DateTime>{};
  final _owners = <String, int>{};
  final _refreshUrls = <String>{};
  Future<void> _queue = Future.value();
  ReaderLease<String?> acquire(String? url) {
    if (url == null || !CatalogOnlinePolicy.artwork(url)) {
      return ReaderLease(Future<String?>.value(), () {});
    }
    final key = stableId(url);
    _owners[key] = (_owners[key] ?? 0) + 1;
    var released = false;
    return ReaderLease(get(url), () {
      if (released) return;
      released = true;
      final count = (_owners[key] ?? 1) - 1;
      if (count <= 0)
        _owners.remove(key);
      else
        _owners[key] = count;
    });
  }

  Future<String?> get(String? url) async {
    if (!CatalogOnlinePolicy.artwork(url)) return null;
    if ((_failedUntil[url]?.isAfter(DateTime.now()) ?? false)) return null;
    final existing = _pending[url];
    if (existing != null) return existing;
    // Bounded admission; scrolling through many titles must not queue unbounded
    // HTTP/decode jobs. A later appearance can retry an unadmitted tile.
    if (_pending.length >= 24) return null;
    final task = _queue.then((_) => _load(url!));
    _pending[url!] = task;
    _queue = task.then<void>((_) {}, onError: (Object _) {});
    try {
      return await task;
    } finally {
      _pending.remove(url);
    }
  }

  Future<String?> _load(String url) async {
    try {
      final directory = await Directory(
        '${(await getTemporaryDirectory()).path}/tangerine-catalog-artwork',
      ).create(recursive: true);
      final file = File('${directory.path}/${stableId(url)}.png');
      final refreshing = _refreshUrls.remove(url);
      if (!refreshing && await file.exists()) {
        final size = await file.length();
        if (size > 0 && size <= 2 * 1024 * 1024) {
          await file.setLastModified(DateTime.now());
          return file.path;
        }
        await file.delete();
      }
      final bytes = await CatalogHttp.bytes(Uri.parse(url), image: true);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width <= 0 ||
            descriptor.height <= 0 ||
            descriptor.width * descriptor.height > 32000000)
          return null;
        final scale = math.min(
          1.0,
          math.min(600 / descriptor.width, 900 / descriptor.height),
        );
        final codec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (descriptor.width * scale).round()),
          targetHeight: math.max(1, (descriptor.height * scale).round()),
        );
        late ui.Image image;
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null || png.lengthInBytes > 2 * 1024 * 1024) return null;
          if (!await _prune(directory, file.path, png.lengthInBytes))
            return null;
          final temp = File('${file.path}.part');
          try {
            await temp.writeAsBytes(png.buffer.asUint8List(), flush: true);
            await temp.rename(file.path);
          } finally {
            if (await temp.exists()) await temp.delete();
          }
        } finally {
          image.dispose();
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
      return file.path;
    } on Object {
      // Missing cover art is common, and must not prevent a metadata match.
      if (_failedUntil.length >= 128)
        _failedUntil.remove(_failedUntil.keys.first);
      _failedUntil[url] = DateTime.now().add(const Duration(minutes: 1));
      return null;
    }
  }

  void retry(String url) => _failedUntil.remove(url);
  Future<void> refresh(String url) async {
    if (!CatalogOnlinePolicy.artwork(url)) return;
    final pending = _pending[url];
    if (pending != null) await pending;
    retry(url);
    // Refresh uses an atomic replacement after successful decode. Other visible
    // owners keep their current file if the network request fails.
    if (_refreshUrls.length >= 128) _refreshUrls.remove(_refreshUrls.first);
    _refreshUrls.add(url);
  }

  Future<bool> _prune(
    Directory directory,
    String protected,
    int incoming,
  ) async {
    final entries = <({File file, FileStat stat})>[];
    await for (final entity in directory.list()) {
      if (entity is File)
        entries.add((file: entity, stat: await entity.stat()));
    }
    var bytes = entries.fold<int>(0, (sum, e) => sum + e.stat.size);
    if (bytes + incoming <= 100 * 1024 * 1024) return true;
    entries.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    for (final entry in entries) {
      final key = entry.file.uri.pathSegments.last.split('.').first;
      if (entry.file.path == protected || _owners.containsKey(key)) continue;
      await entry.file.delete();
      bytes -= entry.stat.size;
      if (bytes + incoming <= 90 * 1024 * 1024) break;
    }
    return bytes + incoming <= 100 * 1024 * 1024;
  }
}
