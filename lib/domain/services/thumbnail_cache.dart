import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/utils/id_utils.dart';
import '../../data/db/app_database.dart';

/// One renderer at a time, a small LRU, and at most 64 MB of regenerable files.
class ThumbnailCache {
  final _pending = <String, Future<String?>>{};
  Future<void> _queue = Future.value();
  Future<String?> forItem(Item item) {
    final key = '${item.id}:${item.modifiedAt}:${item.fileSize}';
    final cached = _pending.remove(key);
    if (cached != null) {
      _pending[key] = cached;
      return cached;
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
    if (item.itemType == 'image') return item.filePath;
    if (!['pdf', 'video'].contains(item.itemType)) return null;
    try {
      final directory = await Directory(
        '${(await getTemporaryDirectory()).path}/studystream-thumbnails',
      ).create(recursive: true);
      final target = File('${directory.path}/${stableId(key)}.png');
      if (await target.exists()) return target.path;
      if (item.itemType == 'pdf') {
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
    await for (final file in directory.list()) {
      if (file is! File) continue;
      final stat = await file.stat();
      total += stat.size;
      files.add((file, stat));
    }
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    for (final entry in files) {
      if (total <= 64 * 1024 * 1024) break;
      await entry.$1.delete();
      total -= entry.$2.size;
    }
  }
}
