import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/id_utils.dart';
import '../../domain/reader/reader_jobs.dart';

/// Regenerable page previews. Encoded memory and disk budgets are separate from
/// scheduler in-flight reservations and the visible page's decoded allocation.
class ReaderThumbnailStore {
  ReaderThumbnailStore(this.documentKey) {
    _owners[documentKey] = (_owners[documentKey] ?? 0) + 1;
  }
  final String documentKey;
  static final _owners = <String, int>{};
  static Future<void> _diskTail = Future.value();
  final _memory = ReaderByteCache<Uint8List>(12 * 1024 * 1024);
  bool _closed = false;
  static const _limit = 64 * 1024 * 1024;
  Future<Directory> _root() async => Directory(
    '${(await getTemporaryDirectory()).path}/tangerine-reader-thumbnails-v1',
  ).create(recursive: true);
  String key(String pageKey, String variant) =>
      '${stableId(documentKey)}-${stableId('$pageKey:$variant')}';
  Future<Uint8List?> read(String key) async {
    if (_closed) return null;
    final memory = _memory.get(key);
    if (memory != null) return memory;
    try {
      final file = File('${(await _root()).path}/$key.png');
      if (!await file.exists() || await file.length() > 2 * 1024 * 1024)
        return null;
      final bytes = await file.readAsBytes();
      if (_closed) return null;
      _memory.put(key, bytes, bytes.length);
      await file.setLastModified(DateTime.now());
      return bytes;
    } on Object {
      return null;
    }
  }

  Future<void> write(String key, Uint8List bytes) async {
    if (_closed || bytes.length > 2 * 1024 * 1024) return;
    _memory.put(key, bytes, bytes.length);
    final write = _diskTail.then((_) async {
      if (_closed) return;
      final root = await _root();
      final target = File('${root.path}/$key.png');
      if (await target.exists()) {
        await target.setLastModified(DateTime.now());
        return;
      }
      final temporary = File('${target.path}.${const Uuid().v4()}.part');
      try {
        await temporary.writeAsBytes(bytes, flush: true);
        if (_closed) return;
        await temporary.rename(target.path);
        await _trim(root);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    });
    _diskTail = write.catchError((Object _) {});
    await _diskTail;
  }

  static Future<void> _trim(Directory root) async {
    final rows = <({File file, int size, DateTime access})>[];
    await for (final file in root.list(followLinks: false)) {
      if (file is! File || !file.path.endsWith('.png')) continue;
      final stat = await file.stat();
      rows.add((file: file, size: stat.size, access: stat.modified));
    }
    final allocated = <String, int>{};
    if (Platform.isMacOS) {
      for (var i = 0; i < rows.length; i += 256) {
        try {
          final result = await const MethodChannel('studystream/folder_access')
              .invokeMapMethod<String, dynamic>('allocatedSizes', {
                'paths': rows
                    .skip(i)
                    .take(256)
                    .map((r) => r.file.path)
                    .toList(),
              });
          for (final entry
              in result?.entries ?? <MapEntry<String, dynamic>>[]) {
            if (entry.value is int && entry.value >= 0)
              allocated[entry.key] = entry.value;
          }
        } on Object {
          /* Logical bytes are the portable fallback. */
        }
      }
    }
    var total = rows.fold<int>(
      0,
      (n, r) => n + (allocated[r.file.path] ?? r.size),
    );
    if (total <= _limit) return;
    rows.sort((a, b) => a.access.compareTo(b.access));
    final protected = _owners.keys.map(stableId).toSet();
    final grace = DateTime.now().subtract(const Duration(minutes: 10));
    for (final row in rows) {
      if (total <= _limit * .9) break;
      final name = row.file.uri.pathSegments.last;
      if (protected.any((id) => name.startsWith('$id-')) ||
          row.access.isAfter(grace))
        continue;
      try {
        await row.file.delete();
        total -= allocated[row.file.path] ?? row.size;
      } on FileSystemException {
        /* Best effort; never delete active publications. */
      }
    }
  }

  void clearMemory() => _memory.clear();
  void dispose() {
    if (_closed) return;
    _closed = true;
    _memory.clear();
    final count = (_owners[documentKey] ?? 1) - 1;
    if (count <= 0) {
      _owners.remove(documentKey);
    } else {
      _owners[documentKey] = count;
    }
  }
}
