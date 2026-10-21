import 'dart:typed_data';
import 'package:xml/xml.dart';
import '../../core/utils/sort_utils.dart';
import 'safe_book_archive.dart';
import 'publication_server.dart';

/// Reads one bounded cover resource; never starts WebKit or renders the book.
abstract final class PublicationCover {
  static bool _image(String path) => RegExp(
    r'\.(png|jpe?g|webp|gif|bmp)$',
    caseSensitive: false,
  ).hasMatch(path);
  static Future<Uint8List?> read(String path, {required bool epub}) async {
    final archive = await SafeBookArchive.open(path);
    String? cover;
    if (!epub) {
      final images =
          archive.entries.keys
              .where(
                (name) =>
                    _image(name) &&
                    !name
                        .split('/')
                        .any(
                          (part) => part.startsWith('.') || part == '__MACOSX',
                        ),
              )
              .toList()
            ..sort(naturalCourseCompare);
      cover = images.firstOrNull;
    } else {
      final container = XmlDocument.parse(
        await archive.text('META-INF/container.xml'),
      );
      final root = container.descendants
          .whereType<XmlElement>()
          .where((node) => node.name.local == 'rootfile')
          .firstOrNull
          ?.getAttribute('full-path');
      if (root == null) return null;
      final package = XmlDocument.parse(await archive.text(root));
      final legacy = package.descendants
          .whereType<XmlElement>()
          .where(
            (node) =>
                node.name.local == 'meta' &&
                node.getAttribute('name') == 'cover',
          )
          .firstOrNull
          ?.getAttribute('content');
      final manifest = package.descendants
          .whereType<XmlElement>()
          .where((node) => node.name.local == 'item')
          .toList();
      final entry =
          manifest
              .where(
                (node) => (node.getAttribute('properties') ?? '')
                    .split(RegExp(r'\s+'))
                    .contains('cover-image'),
              )
              .firstOrNull ??
          manifest
              .where(
                (node) => legacy != null && node.getAttribute('id') == legacy,
              )
              .firstOrNull;
      final href = entry?.getAttribute('href');
      if (href != null) {
        final uri = Uri.parse(href);
        if (uri.hasScheme || uri.hasAuthority) return null;
        cover = PublicationServer.resolve(root, href);
      }
    }
    if (cover == null || !_image(cover)) return null;
    return archive.read(cover, limit: 8 * 1024 * 1024);
  }
}
