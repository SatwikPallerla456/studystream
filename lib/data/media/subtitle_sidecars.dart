import 'dart:io';
import 'package:path/path.dart' as p;
import '../../domain/catalog/catalog_hints.dart';

/// Local companions only. Remote library paths are never enumerated on a client.
abstract final class SubtitleSidecars {
  static const extensions = {'srt', 'vtt', 'ass', 'ssa', 'idx'};
  static final _marker = RegExp(
    r'\{edition-[^{}]+\}|\[edition-[^\[\]]+\]',
    caseSensitive: false,
  );
  static String _stem(String path) => p
      .basenameWithoutExtension(path)
      .replaceAll(_marker, '')
      .replaceAll(RegExp(r'[._\s]+'), ' ')
      .trim()
      .toLowerCase();

  static String? _mediaEdition(String path) {
    for (final component in p.split(path.replaceAll('\\', '/')).reversed) {
      final value = CatalogHints.edition(component);
      if (value != null) return value;
    }
    return null;
  }

  static Future<List<File>> _siblings(String path) async {
    final files = <File>[];
    var count = 0;
    await for (final entry in File(path).parent.list(followLinks: false)) {
      if (++count > 2000)
        throw const FormatException(
          'This folder is too large to scan for subtitles. Choose a file instead.',
        );
      if (entry is File) files.add(entry);
    }
    return files;
  }

  static Future<void> validate(String mediaName, String subtitlePath) async {
    final file = File(subtitlePath);
    final suffix = p.extension(subtitlePath);
    final extension = suffix.isEmpty ? '' : suffix.substring(1).toLowerCase();
    if (!extensions.contains(extension) ||
        !await file.exists() ||
        await file.length() > 16 * 1024 * 1024) {
      throw const FormatException(
        'Choose a supported subtitle file smaller than 16 MiB.',
      );
    }
    final edition = CatalogHints.edition(p.basename(subtitlePath));
    if (edition != null && edition != _mediaEdition(mediaName)) {
      throw const FormatException(
        'This subtitle names a different edition of the title.',
      );
    }
    if (extension == 'idx') {
      final stem = p.basenameWithoutExtension(subtitlePath).toLowerCase();
      final companions = await _siblings(subtitlePath);
      final sub = companions.where(
        (f) => p.basename(f.path).toLowerCase() == '$stem.sub',
      );
      if (sub.isEmpty || await sub.first.length() > 64 * 1024 * 1024) {
        throw const FormatException(
          'An IDX subtitle needs its matching SUB file in the same folder (maximum 64 MiB).',
        );
      }
    }
  }

  static Future<List<File>> discover(String mediaPath) async {
    if (mediaPath.startsWith('remote:')) return [];
    final stem = _stem(mediaPath),
        edition = _mediaEdition(mediaPath),
        fileEdition = CatalogHints.edition(p.basename(mediaPath));
    final candidates = <File>[];
    for (final file in await _siblings(mediaPath)) {
      final ext = p.extension(file.path).toLowerCase();
      if (ext.isEmpty || !extensions.contains(ext.substring(1))) continue;
      // Unlabelled sidecars are ambiguous for a named cut. They remain available
      // through explicit selection, but never appear as automatic companions.
      final sidecarEdition = CatalogHints.edition(p.basename(file.path));
      if (fileEdition != null && sidecarEdition != fileEdition) continue;
      if (sidecarEdition != null && sidecarEdition != edition) continue;
      final name = _stem(file.path);
      if (name != stem && !name.startsWith('$stem ')) continue;
      final suffix = name.substring(stem.length).trim();
      if (suffix.isNotEmpty &&
          !RegExp(
            r'^(?:[a-z]{2,3}|forced|sdh|cc|default|hearing impaired)(?: (?:[a-z]{2,3}|forced|sdh|cc|default|hearing impaired))*$',
          ).hasMatch(suffix))
        continue;
      try {
        await validate(mediaPath, file.path);
        candidates.add(file);
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    candidates.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return candidates.take(50).toList();
  }
}
