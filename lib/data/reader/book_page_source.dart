import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../domain/reader/reader_jobs.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../../core/utils/sort_utils.dart';
import 'safe_book_archive.dart';
import 'publication_server.dart';
import 'publication_content.dart';

class BookPage {
  const BookPage({this.image, this.html, this.title = ''});
  final Uint8List? image;
  final String? html;
  final String title;
}

enum ReaderCapability {
  rasterRender,
  intrinsicGeometry,
  nativeText,
  textSelection,
  textSearch,
  publicationMetrics,
  ocr,
}

abstract class BookPageSource {
  Set<ReaderCapability> get capabilities;
  int get pageCount;
  bool get reflowable;
  bool get publication;
  bool publicationPage(int canonicalPage);
  List<String> get titles;
  String locator(int canonicalPage);
  Future<BookPage> load(int canonicalPage, {ReaderCancellation? cancellation});
  Future<ui.Size> geometry(
    int canonicalPage, {
    ReaderCancellation? cancellation,
  });
  Future<void> dispose();
}

class ArchiveBookSource implements BookPageSource {
  ArchiveBookSource._(
    this.archive,
    this.paths,
    this.titles,
    this.reflowable, [
    this.contents = const [],
  ]);
  final List<PublicationDestination> contents;
  final _textCache = ReaderByteCache<String>(8 * 1024 * 1024);
  final SafeBookArchive archive;
  final List<String> paths;
  @override
  final List<String> titles;
  @override
  final bool reflowable;
  bool _disposed = false;
  @override
  bool get publication => paths.any(
    (path) =>
        RegExp(r'\.(xhtml|html|htm|svg)$', caseSensitive: false).hasMatch(path),
  );
  @override
  bool publicationPage(int canonicalPage) => RegExp(
    r'\.(xhtml|html|htm|svg)$',
    caseSensitive: false,
  ).hasMatch(paths[canonicalPage - 1]);
  Future<PublicationServer>? _publicationServer;
  Future<PublicationServer> publicationServer() =>
      _publicationServer ??= PublicationServer.open(archive);
  static Future<ArchiveBookSource> open(
    String path, {
    required bool epub,
  }) async {
    final archive = await SafeBookArchive.open(path);
    if (!epub) {
      final pages =
          archive.entries.keys
              .where(
                (n) =>
                    RegExp(
                      r'\.(png|jpe?g|webp|gif|bmp)$',
                      caseSensitive: false,
                    ).hasMatch(n) &&
                    !n
                        .split('/')
                        .any((s) => s.startsWith('.') || s == '__MACOSX'),
              )
              .toList()
            ..sort(naturalCourseCompare);
      if (pages.isEmpty)
        throw const FormatException('No supported images in this comic');
      return ArchiveBookSource._(
        archive,
        pages,
        pages.map(p.posix.basename).toList(),
        false,
      );
    }
    final container = XmlDocument.parse(
      await archive.text('META-INF/container.xml'),
    );
    final root = container.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'rootfile')
        .firstOrNull
        ?.getAttribute('full-path');
    if (root == null) throw const FormatException('EPUB package missing');
    final package = XmlDocument.parse(await archive.text(root));
    final manifest = <String, String>{};
    String? nav, ncx;
    for (final entry in package.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'item',
    )) {
      final id = entry.getAttribute('id'), href = entry.getAttribute('href');
      if (id != null && href != null) {
        final uri = Uri.parse(href);
        if (uri.hasScheme || uri.hasAuthority)
          throw const FormatException('External EPUB resource');
        manifest[id] = PublicationServer.resolve(root, href);
        if ((entry.getAttribute('properties') ?? '')
            .split(RegExp(r'\s+'))
            .contains('nav'))
          nav = manifest[id];
        if (entry.getAttribute('media-type') == 'application/x-dtbncx+xml')
          ncx = manifest[id];
      }
    }
    final pages = <String>[];
    for (final spine in package.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'itemref' && e.getAttribute('linear') != 'no',
    )) {
      final resource = manifest[spine.getAttribute('idref')];
      if (resource != null) pages.add(resource);
      if (pages.length > 10000)
        throw const FormatException(
          'EPUB reading order exceeds 10,000 sections',
        );
    }
    if (pages.isEmpty)
      throw const FormatException('EPUB reading order missing');
    final fixed = package.descendants.whereType<XmlElement>().any(
      (e) =>
          e.name.local == 'meta' &&
          e.getAttribute('property') == 'rendition:layout' &&
          e.innerText.trim() == 'pre-paginated',
    );
    final titles = pages
        .map((path) => p.posix.basenameWithoutExtension(path))
        .toList();
    final contents = <PublicationDestination>[];
    for (final candidate in [
      if (nav != null) (nav, false),
      if (ncx != null) (ncx, true),
    ]) {
      try {
        final entries = await publicationContents(
          await archive.text(candidate.$1!),
          ncx: candidate.$2,
        );
        final named = <int>{};
        for (final entry in entries) {
          try {
            final uri = Uri.parse(entry.href);
            // Fragment-only hrefs refer to the navigation resource itself.
            final path = uri.path.isEmpty
                ? candidate.$1!
                : PublicationServer.resolve(candidate.$1!, entry.href);
            if (!archive.entries.containsKey(path) ||
                !RegExp(
                  r'\.(xhtml|html|htm|svg)$',
                  caseSensitive: false,
                ).hasMatch(path))
              continue;
            var index = pages.indexOf(path);
            if (index < 0) {
              // Auxiliary destinations do not shift existing canonical spine locators.
              pages.add(path);
              titles.add(p.posix.basenameWithoutExtension(path));
              index = pages.length - 1;
            }
            contents.add(
              PublicationDestination(
                entry.title,
                index + 1,
                uri.fragment,
                entry.depth,
              ),
            );
            if (named.add(index)) titles[index] = entry.title;
          } on FormatException {
            /* Ignore an invalid destination, retain other chapters. */
          }
        }
        if (contents.isNotEmpty) break;
      } on Object {
        /* A malformed contents resource must not prevent reading. */
      }
    }
    return ArchiveBookSource._(archive, pages, titles, !fixed, contents);
  }

  /// Bounded, cancellable batches. The cursor continues inside a dense chapter.
  Future<PublicationSearchBatch> search(
    String query, {
    int startPage = 1,
    int startOffset = 0,
    ReaderCancellation? cancellation,
  }) async {
    query = query.trim();
    if (query.isEmpty || query.length > 200)
      throw ArgumentError('Search requires 1–200 characters');
    final pattern = RegExp(
      RegExp.escape(query),
      caseSensitive: false,
      unicode: true,
    );
    final hits = <PublicationSearchHit>[], skipped = <int>[];
    var examined = 0;
    for (var page = startPage.clamp(1, pageCount); page <= pageCount; page++) {
      cancellation?.check();
      if (examined++ >= 24)
        return PublicationSearchBatch(hits, page, 0, skipped);
      if (!publicationPage(page)) continue;
      try {
        final key = locator(page);
        var text = _textCache.get(key);
        if (text == null) {
          text = await publicationText(await archive.text(key));
          cancellation?.check();
          if (_disposed) throw const ReaderCancelled();
          _textCache.put(key, text, text.length * 2);
        }
        for (final match in pattern.allMatches(
          text,
          page == startPage ? startOffset.clamp(0, text.length) : 0,
        )) {
          cancellation?.check();
          hits.add(
            PublicationSearchHit(
              page,
              match.start,
              match.end,
              text.substring(match.start, match.end),
              text
                  .substring(
                    (match.start - 65).clamp(0, text.length),
                    (match.end + 100).clamp(0, text.length),
                  )
                  .replaceAll(RegExp(r'\s+'), ' '),
            ),
          );
          if (hits.length >= 60)
            return PublicationSearchBatch(hits, page, match.end, skipped);
        }
      } on ReaderCancelled {
        rethrow;
      } on Object {
        skipped.add(page);
      }
    }
    return PublicationSearchBatch(hits, null, 0, skipped);
  }

  void clearRegenerableCaches() => _textCache.clear();

  @override
  Set<ReaderCapability> get capabilities => {
    ReaderCapability.intrinsicGeometry,
    if (publication) ...{
      ReaderCapability.nativeText,
      ReaderCapability.textSelection,
      ReaderCapability.textSearch,
      ReaderCapability.publicationMetrics,
    } else
      ReaderCapability.rasterRender,
  };
  @override
  int get pageCount => paths.length;
  @override
  String locator(int canonicalPage) => paths[canonicalPage - 1];
  @override
  Future<BookPage> load(
    int canonicalPage, {
    ReaderCancellation? cancellation,
  }) async {
    cancellation?.check();
    if (_disposed) throw StateError('Reader closed');
    final path = paths[canonicalPage - 1];
    if (!publicationPage(canonicalPage))
      return BookPage(
        image: await archive.read(
          path,
          limit: 32 * 1024 * 1024,
          cancellation: cancellation,
        ),
        title: titles[canonicalPage - 1],
      );
    final html = await archive.text(path);
    cancellation?.check();
    if (_disposed) throw const ReaderCancelled();
    return BookPage(html: html, title: titles[canonicalPage - 1]);
  }

  @override
  Future<ui.Size> geometry(
    int canonicalPage, {
    ReaderCancellation? cancellation,
  }) async {
    final page = await load(canonicalPage, cancellation: cancellation);
    cancellation?.check();
    if (page.image == null) {
      final xml = XmlDocument.parse(page.html!);
      final viewport =
          xml.descendants
              .whereType<XmlElement>()
              .where(
                (node) =>
                    node.name.local == 'meta' &&
                    node.getAttribute('name') == 'viewport',
              )
              .firstOrNull
              ?.getAttribute('content') ??
          '';
      final body = xml.descendants
          .whereType<XmlElement>()
          .where((node) => node.name.local == 'body')
          .firstOrNull;
      double? value(String name) => double.tryParse(
        RegExp('$name\\s*[=:]\\s*([0-9.]+)', caseSensitive: false)
                .firstMatch('$viewport;${body?.getAttribute('style') ?? ''}')
                ?.group(1) ??
            '',
      );
      final svg = xml.rootElement.name.local == 'svg' ? xml.rootElement : null;
      final viewBox = svg
          ?.getAttribute('viewBox')
          ?.trim()
          .split(RegExp(r'[ ,]+'))
          .map(double.tryParse)
          .toList();
      final width =
              value('width') ??
              double.tryParse(svg?.getAttribute('width') ?? '') ??
              (viewBox?.length == 4 ? viewBox![2] : null) ??
              800,
          height =
              value('height') ??
              double.tryParse(svg?.getAttribute('height') ?? '') ??
              (viewBox?.length == 4 ? viewBox![3] : null) ??
              1100;
      if (!width.isFinite ||
          !height.isFinite ||
          width < 1 ||
          height < 1 ||
          width > 24000 ||
          height > 24000 ||
          width * height > 80000000)
        throw const FormatException('Publication geometry exceeds limits');
      return ui.Size(width, height);
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(page.image!);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width > 24000 ||
          descriptor.height > 24000 ||
          descriptor.width * descriptor.height > 80000000)
        throw const FormatException('Page geometry exceeds limits');
      return ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _textCache.clear();
    await (await _publicationServer)?.dispose();
  }
}
