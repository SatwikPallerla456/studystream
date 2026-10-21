import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/utils/id_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/reader/publication_cover.dart';
import '../reader/reader_jobs.dart';
import 'dart:math' as math;

/// One renderer at a time, a small LRU, and at most 64 MB of regenerable files.
class ThumbnailCache {
  final _pending = <String, Future<String?>>{};
  Future<void> _queue = Future.value();
  final _owners = <String, int>{};
  String _key(Item item) =>
      'v3:${item.id}:${item.fingerprint ?? '${item.modifiedAt}:${item.fileSize}'}:320:rgba';
  ReaderLease<String?> acquire(Item item) {
    final key = _key(item);
    _owners[key] = (_owners[key] ?? 0) + 1;
    var released = false;
    return ReaderLease(forItem(item), () {
      if (released) return;
      released = true;
      final count = (_owners[key] ?? 1) - 1;
      if (count <= 0) {
        _owners.remove(key);
      } else {
        _owners[key] = count;
      }
    });
  }

  Future<String?> forItem(Item item) {
    final key = _key(item);
    final cached = _pending.remove(key);
    if (cached != null) {
      _pending[key] = cached;
      return cached.then((path) async {
        if (path != null && await File(path).exists()) {
          try {
            await File(path).setLastModified(DateTime.now());
          } on FileSystemException {
            /* Best-effort access time. */
          }
          return path;
        }
        if (identical(_pending[key], cached)) _pending.remove(key);
        if (path == null) return null;
        // A pruned disk result is a cache miss, never a permanently stale URI.
        return forItem(item);
      });
    }
    if (_pending.length >= 96) _pending.remove(_pending.keys.first);
    final result = _queue.then((_) => _generate(item, key));
    _pending[key] = result;
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<String?> _generate(Item item, String key) async {
    if (item.unavailable || item.filePath.startsWith('remote:')) return null;
    final source = File(item.filePath);
    if (!await source.exists()) return null;
    if (!['image', 'pdf', 'video', 'cbz', 'epub'].contains(item.itemType))
      return null;
    try {
      final directory = await Directory(
        '${(await getTemporaryDirectory()).path}/studystream-thumbnails',
      ).create(recursive: true);
      final target = File('${directory.path}/${stableId(key)}.png');
      if (await target.exists()) {
        await target.setLastModified(DateTime.now());
        return target.path;
      }
      if ({'image', 'cbz', 'epub'}.contains(item.itemType)) {
        if (item.itemType == 'image' &&
            await source.length() > 32 * 1024 * 1024)
          return null;
        final bytes = item.itemType == 'image'
            ? await source.readAsBytes()
            : await PublicationCover.read(
                item.filePath,
                epub: item.itemType == 'epub',
              );
        if (bytes == null) return null;
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        ui.ImageDescriptor? descriptor;
        try {
          descriptor = await ui.ImageDescriptor.encoded(buffer);
          if (descriptor.width * descriptor.height > 80000000) return null;
          final scale = math.min(
            1.0,
            math.min(320 / descriptor.width, 640 / descriptor.height),
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
            if (png != null)
              await target.writeAsBytes(png.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        } finally {
          descriptor?.dispose();
          buffer.dispose();
        }
      } else if (item.itemType == 'pdf') {
        final document = await PdfDocument.openFile(item.filePath);
        try {
          if (document.pages.isEmpty) return null;
          final page = document.pages.first;
          final bitmap = await page.render(
            width: 320,
            height: (320 * page.height / page.width).clamp(1, 640).round(),
          );
          if (bitmap == null) return null;
          try {
            final image = await bitmap.createImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (bytes != null) {
                await target.writeAsBytes(bytes.buffer.asUint8List());
              }
            } finally {
              image.dispose();
            }
          } finally {
            bitmap.dispose();
          }
        } finally {
          await document.dispose();
        }
      } else if (Platform.isMacOS) {
        await const MethodChannel(
          'studystream/folder_access',
        ).invokeMethod<String>('thumbnail', {
          'path': item.filePath,
          'output': target.path,
        });
      }
      await _prune(directory);
      return await target.exists() ? target.path : null;
    } on Object {
      return null;
    } // Artwork failure never blocks opening the source.
  }

  Future<void> _prune(Directory directory) async {
    final files = <(File, FileStat)>[];
    var total = 0;
    await for (final file in directory.list(followLinks: false)) {
      if (file is! File) continue;
      final stat = await file.stat();
      files.add((file, stat));
    }
    // macOS reports allocated disk bytes; other platforms and failed resource
    // reads explicitly fall back to logical size. This is not a decoded/RSS cap.
    final sizes = <String, int>{
      for (final entry in files) entry.$1.path: entry.$2.size,
    };
    if (Platform.isMacOS) {
      for (var start = 0; start < files.length; start += 512) {
        try {
          final allocated =
              await const MethodChannel(
                'studystream/folder_access',
              ).invokeMapMethod<String, dynamic>('allocatedSizes', {
                'paths': files
                    .skip(start)
                    .take(512)
                    .map((e) => e.$1.path)
                    .toList(),
              });
          for (final entry
              in allocated?.entries ?? <MapEntry<String, dynamic>>[]) {
            if (sizes.containsKey(entry.key) &&
                entry.value is int &&
                entry.value >= 0)
              sizes[entry.key] = entry.value as int;
          }
        } on PlatformException {
          /* Keep logical byte fallback. */
        } on MissingPluginException {
          /* Keep logical byte fallback. */
        }
      }
    }
    total = sizes.values.fold(0, (sum, value) => sum + value);
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    if (total <= 64 * 1024 * 1024) return;
    final protected = _owners.keys.map((key) => '${stableId(key)}.png').toSet();
    for (final entry in files) {
      if (total <= (64 * 1024 * 1024 * .9).floor()) break;
      if (protected.contains(entry.$1.uri.pathSegments.last) ||
          DateTime.now().difference(entry.$2.modified) <
              const Duration(minutes: 10))
        continue;
      try {
        await entry.$1.delete();
        total -= sizes[entry.$1.path] ?? entry.$2.size;
      } on FileSystemException {
        /* Another owner/process may have changed it. */
      }
    }
  }
}
