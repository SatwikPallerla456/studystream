import 'dart:isolate';

import 'package:xml/xml.dart';

/// Shared sanitization keeps the server and UTF-16 search/anchor model aligned.
XmlDocument publicationDocument(String markup) {
  final xml = XmlDocument.parse(markup);
  // HTML parsers normalize CR/CRLF before constructing DOM text nodes. Apply
  // that same rule before indexing and serving so offsets remain UTF-16 aligned.
  for (final text in xml.descendants.whereType<XmlText>()) {
    text.value = text.value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }
  for (final node in xml.descendants.whereType<XmlElement>().toList()) {
    if ({
      'script',
      'iframe',
      'object',
      'embed',
      'base',
      'form',
      'foreignObject',
    }.contains(node.name.local)) {
      node.parent?.children.remove(node);
      continue;
    }
    node.attributes.removeWhere(
      (a) =>
          a.name.local.toLowerCase().startsWith('on') ||
          a.name.local == 'srcdoc',
    );
    for (final attr in node.attributes.toList()) {
      if (!{'src', 'href', 'poster', 'action'}.contains(attr.name.local))
        continue;
      final value = attr.value.trim();
      if (value.startsWith('#')) continue;
      if (Uri.tryParse(value)?.hasScheme != false || value.startsWith('/')) {
        node.attributes.remove(attr);
      }
    }
  }
  return xml;
}

Future<String> publicationText(String markup) => Isolate.run(() {
  final xml = publicationDocument(markup);
  final root =
      xml.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'body')
          .firstOrNull ??
      xml.rootElement;
  final text = StringBuffer();
  var nodes = 0;
  for (final node in root.descendants.whereType<XmlText>()) {
    if (node.ancestors.whereType<XmlElement>().any(
      (e) => {'script', 'style', 'noscript'}.contains(e.name.local),
    ))
      continue;
    if (++nodes > 250000 || text.length + node.value.length > 8000000) {
      throw const FormatException('Publication text exceeds the section limit');
    }
    text.write(node.value);
  }
  return text.toString();
});

class PublicationDestination {
  const PublicationDestination(
    this.title,
    this.page,
    this.fragment,
    this.depth,
  );
  final String title, fragment;
  final int page, depth;
}

class PublicationSearchHit {
  const PublicationSearchHit(
    this.page,
    this.start,
    this.end,
    this.quote,
    this.excerpt,
  );
  final int page, start, end;
  final String quote, excerpt;
}

class PublicationSearchBatch {
  const PublicationSearchBatch(
    this.hits,
    this.nextPage,
    this.nextOffset,
    this.skipped,
  );
  final List<PublicationSearchHit> hits;
  final int? nextPage;
  final int nextOffset;
  final List<int> skipped;
}

/// Parse only the semantic contents tree, never landmarks or arbitrary links.
Future<List<({String title, String href, int depth})>> publicationContents(
  String markup, {
  required bool ncx,
}) => Isolate.run(() {
  final xml = XmlDocument.parse(markup);
  final result = <({String title, String href, int depth})>[];
  final root = ncx
      ? xml.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'navMap')
            .firstOrNull
      : xml.descendants
            .whereType<XmlElement>()
            .where(
              (e) =>
                  e.name.local == 'nav' &&
                  e.attributes.any(
                    (a) =>
                        (a.name.local == 'type' &&
                            a.value.split(RegExp(r'\s+')).contains('toc')) ||
                        (a.name.local == 'role' && a.value == 'doc-toc'),
                  ),
            )
            .firstOrNull;
  if (root == null) return result;
  for (final node in root.descendants.whereType<XmlElement>()) {
    if (result.length >= 10000) break;
    String? title, href;
    if (ncx && node.name.local == 'navPoint') {
      title = node.childElements
          .where((e) => e.name.local == 'navLabel')
          .firstOrNull
          ?.innerText;
      href = node.childElements
          .where((e) => e.name.local == 'content')
          .firstOrNull
          ?.getAttribute('src');
    } else if (!ncx && node.name.local == 'a') {
      title = node.innerText;
      href = node.getAttribute('href');
    }
    if (title == null || href == null) continue;
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) continue;
    final depth = node.ancestors
        .whereType<XmlElement>()
        .where((e) => e.name.local == (ncx ? 'navPoint' : 'ol'))
        .length;
    result.add((
      title: title.substring(0, title.length.clamp(0, 500)),
      href: href,
      depth: (depth - (ncx ? 0 : 1)).clamp(0, 12),
    ));
  }
  return result;
});
