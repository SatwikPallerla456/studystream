import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import '../../core/utils/id_utils.dart';
import '../catalog/catalog_online_policy.dart';
import '../catalog/online_catalog_provider.dart';

/// Regenerable provider artwork. 100 MiB disk LRU, 2 MiB downloads, 600x900
/// decoded targets, 32 MP source ceiling, one decode at a time. Never overwrites
/// Items.thumbnailPath or a user's media. All hosted output is normalized PNG.
class CatalogArtworkCache {
  static final instance = CatalogArtworkCache();
  final _pending = <String, Future<String?>>{};
  final _failedUntil = <String, DateTime>{};
  Future<void> _queue = Future.value();
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
      if (await file.exists()) {
        await file.setLastModified(DateTime.now());
        return file.path;
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
          final temp = File('${file.path}.part');
          await temp.writeAsBytes(png.buffer.asUint8List(), flush: true);
          await temp.rename(file.path);
        } finally {
          image.dispose();
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
      await _prune(directory, file.path);
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

  Future<void> _prune(Directory directory, String protected) async {
    final entries = <({File file, FileStat stat})>[];
    await for (final entity in directory.list()) {
      if (entity is File)
        entries.add((file: entity, stat: await entity.stat()));
    }
    var bytes = entries.fold<int>(0, (sum, e) => sum + e.stat.size);
    if (bytes <= 100 * 1024 * 1024) return;
    entries.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    for (final entry in entries) {
      if (entry.file.path == protected ||
          DateTime.now().difference(entry.stat.modified).inMinutes < 10)
        continue;
      await entry.file.delete();
      bytes -= entry.stat.size;
      if (bytes <= 90 * 1024 * 1024) break;
    }
  }
}
