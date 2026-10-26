import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

/// Durable positions use an unrotated source page, independently of layout.
class ReaderLocator {
  const ReaderLocator({
    required this.resourceId,
    required this.revision,
    required this.pageKey,
    required this.page,
    this.point = Offset.zero,
    this.fit = 'contain',
    this.zoom = 1,
    this.textOffset,
    this.textQuote,
    this.textBias = .2,
    this.viewState,
  });
  final String resourceId, revision, pageKey, fit;
  final int page;
  final Offset point;
  final double zoom;
  final int? textOffset;
  final String? textQuote;
  final double textBias;
  final Map<String, dynamic>? viewState;
  String encode() => jsonEncode({
    'version': 1,
    'resource': resourceId,
    'revision': revision,
    'pageKey': pageKey,
    'page': page,
    'x': point.dx,
    'y': point.dy,
    'fit': fit,
    'zoom': zoom,
    if (textOffset != null) 'textOffset': textOffset,
    if (textQuote != null) 'textQuote': textQuote,
    if (textOffset != null) 'textBias': textBias,
    if (viewState != null) 'viewState': viewState,
  });
  static ReaderLocator? decode(String? value) {
    if (value == null || value.length > 4096) return null;
    try {
      final data = jsonDecode(value);
      if (data is! Map ||
          data['version'] != 1 ||
          data['resource'] is! String ||
          data['revision'] is! String ||
          data['pageKey'] is! String ||
          data['page'] is! int ||
          data['page'] < 1)
        return null;
      double bounded(String key, double min, double max, double fallback) {
        final n = data[key];
        return n is num && n.isFinite ? n.toDouble().clamp(min, max) : fallback;
      }

      return ReaderLocator(
        resourceId: data['resource'],
        revision: data['revision'],
        pageKey: data['pageKey'],
        page: data['page'],
        point: Offset(bounded('x', 0, 1, 0), bounded('y', 0, 1, 0)),
        fit: {'contain', 'fitWidth', 'fill'}.contains(data['fit'])
            ? data['fit']
            : 'contain',
        zoom: bounded('zoom', 1, 5, 1),
        textOffset:
            data['textOffset'] is int &&
                data['textOffset'] >= 0 &&
                data['textOffset'] <= 8000000
            ? data['textOffset']
            : null,
        textQuote:
            data['textQuote'] is String &&
                (data['textQuote'] as String).length <= 120
            ? data['textQuote']
            : null,
        textBias: bounded('textBias', 0, 1, .2),
        viewState: data['viewState'] is Map<String, dynamic>
            ? ReaderViewportState.decode(data['viewState'])?.toJson()
            : null,
      );
    } on Object {
      return null;
    }
  }

  bool compatible(String resource, String contentRevision) =>
      resourceId == resource && revision == contentRevision;
}

/// Device-local raw viewport state is distinct from a portable source anchor.
/// It is replayed only in the same renderer, layout, fit and logical viewport geometry.
/// Cross-device transport intentionally retains only ReaderLocator's anchor.
class ReaderViewportState {
  const ReaderViewportState({
    required this.renderer,
    required this.layout,
    required this.fit,
    required this.viewport,
    required this.pageSize,
    required this.scale,
    required this.offset,
    required this.focalPoint,
  });
  final String renderer, layout, fit;
  final Size viewport, pageSize;
  final double scale;
  final Offset offset, focalPoint;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'renderer': renderer,
    'layout': layout,
    'fit': fit,
    'width': viewport.width,
    'height': viewport.height,
    'pageWidth': pageSize.width,
    'pageHeight': pageSize.height,
    'scale': scale,
    'offsetX': offset.dx,
    'offsetY': offset.dy,
    'focalX': focalPoint.dx,
    'focalY': focalPoint.dy,
  };
  static ReaderViewportState? decode(Map<String, dynamic>? value) {
    if (value == null || value['version'] != 1) return null;
    for (final key in ['renderer', 'layout', 'fit']) {
      if (value[key] is! String || (value[key] as String).length > 512)
        return null;
    }
    bool number(String key, double min, double max) =>
        value[key] is num &&
        (value[key] as num).isFinite &&
        value[key] >= min &&
        value[key] <= max;
    for (final key in ['width', 'height', 'pageWidth', 'pageHeight']) {
      if (!number(key, .001, 10000000)) return null;
    }
    if (!number('scale', .001, 10000) ||
        !number('offsetX', -100000000, 100000000) ||
        !number('offsetY', -100000000, 100000000) ||
        !number('focalX', 0, 1) ||
        !number('focalY', 0, 1))
      return null;
    double n(String key) => (value[key] as num).toDouble();
    return ReaderViewportState(
      renderer: value['renderer'],
      layout: value['layout'],
      fit: value['fit'],
      viewport: Size(n('width'), n('height')),
      pageSize: Size(n('pageWidth'), n('pageHeight')),
      scale: n('scale'),
      offset: Offset(n('offsetX'), n('offsetY')),
      focalPoint: Offset(n('focalX'), n('focalY')),
    );
  }

  bool compatible({
    required String renderer,
    required String layout,
    required String fit,
    required Size viewport,
    required Size pageSize,
  }) =>
      this.renderer == renderer &&
      this.layout == layout &&
      this.fit == fit &&
      (this.viewport.width - viewport.width).abs() < .5 &&
      (this.viewport.height - viewport.height).abs() < .5 &&
      (this.pageSize.width - pageSize.width).abs() < .5 &&
      (this.pageSize.height - pageSize.height).abs() < .5;
}

/// Forward/inverse affine transform for normalized, unrotated page-local points.
/// Crop origin is in source units; pan is in viewport pixels after zoom.
class PageTransform {
  PageTransform({
    required this.crop,
    required this.viewport,
    this.rotation = 0,
    this.fit = 'contain',
    this.zoom = 1,
    this.pan = Offset.zero,
  }) {
    if (![
          crop.left,
          crop.top,
          crop.right,
          crop.bottom,
          viewport.width,
          viewport.height,
          pan.dx,
          pan.dy,
        ].every((value) => value.isFinite) ||
        !{'contain', 'fitWidth', 'fill'}.contains(fit) ||
        crop.width <= 0 ||
        crop.height <= 0 ||
        viewport.isEmpty ||
        !{0, 90, 180, 270}.contains(rotation) ||
        !zoom.isFinite ||
        zoom <= 0) {
      throw const FormatException('Invalid page geometry');
    }
  }
  final Rect crop;
  final Size viewport;
  final int rotation;
  final String fit;
  final double zoom;
  final Offset pan;
  Size get rotatedSize => rotation == 90 || rotation == 270
      ? Size(crop.height, crop.width)
      : crop.size;
  double get scale {
    final x = viewport.width / rotatedSize.width,
        y = viewport.height / rotatedSize.height;
    return (fit == 'fitWidth'
            ? x
            : fit == 'fill'
            ? math.max(x, y)
            : math.min(x, y)) *
        zoom;
  }

  Offset get origin =>
      Offset(
        (viewport.width - rotatedSize.width * scale) / 2,
        (viewport.height - rotatedSize.height * scale) / 2,
      ) +
      pan;
  Offset toViewport(Offset normalized) {
    final x = normalized.dx * crop.width, y = normalized.dy * crop.height;
    final rotated = switch (rotation) {
      90 => Offset(crop.height - y, x),
      180 => Offset(crop.width - x, crop.height - y),
      270 => Offset(y, crop.width - x),
      _ => Offset(x, y),
    };
    return origin + rotated * scale;
  }

  Offset toPage(Offset viewportPoint, {bool clamp = true}) {
    final local = (viewportPoint - origin) / scale;
    final p = switch (rotation) {
      90 => Offset(local.dy, crop.height - local.dx),
      180 => Offset(crop.width - local.dx, crop.height - local.dy),
      270 => Offset(crop.width - local.dy, local.dx),
      _ => local,
    };
    final normalized = Offset(p.dx / crop.width, p.dy / crop.height);
    return clamp
        ? Offset(normalized.dx.clamp(0, 1), normalized.dy.clamp(0, 1))
        : normalized;
  }

  Offset sourceToViewport(Offset sourcePoint) => toViewport(
    Offset(
      (sourcePoint.dx - crop.left) / crop.width,
      (sourcePoint.dy - crop.top) / crop.height,
    ),
  );
  Offset viewportToSource(Offset point) {
    final p = toPage(point, clamp: false);
    return crop.topLeft + Offset(p.dx * crop.width, p.dy * crop.height);
  }
}

class CanonicalPage {
  const CanonicalPage(this.index, this.key, this.size);
  final int index;
  final String key;
  final Size size;
  bool get landscape => size.width > size.height;
}

/// Source numbering is never changed by cover, pairing, RTL or window width.
class PresentationMap {
  PresentationMap(
    List<CanonicalPage> pages, {
    bool spreads = false,
    bool coverSingle = true,
    Set<int> singlePages = const {},
    Set<int> pairingStarts = const {},
  }) {
    final result = <List<int>>[];
    var i = 0;
    while (i < pages.length) {
      final page = pages[i];
      final next = i + 1 < pages.length ? pages[i + 1] : null;
      final single =
          !spreads ||
          (i == 0 && coverSingle) ||
          page.landscape ||
          singlePages.contains(page.index) ||
          next == null ||
          next.landscape ||
          singlePages.contains(next.index) ||
          pairingStarts.contains(next.index);
      result.add([page.index, if (!single) next!.index]);
      i += single ? 1 : 2;
    }
    cells = List.unmodifiable(
      result.map((cell) => List<int>.unmodifiable(cell)),
    );
    _cellByPage = {
      for (var i = 0; i < cells.length; i++)
        for (final page in cells[i]) page: i,
    };
  }
  late final List<List<int>> cells;
  late final Map<int, int> _cellByPage;
  int cellFor(int canonicalPage) => _cellByPage[canonicalPage] ?? 0;
  List<int> pagesFor(int canonicalPage) => cells[cellFor(canonicalPage)];
  int advance(int canonicalPage, bool forward) {
    final index = (cellFor(canonicalPage) + (forward ? 1 : -1)).clamp(
      0,
      cells.length - 1,
    );
    return cells[index].first;
  }
}

class ContinuousPageLayout {
  ContinuousPageLayout(
    List<CanonicalPage> pages,
    double width, {
    double gap = 8,
  }) {
    offsets = [0];
    for (final page in pages) {
      offsets.add(
        offsets.last + width * page.size.height / page.size.width + gap,
      );
    }
  }
  late final List<double> offsets;
  int pageAt(double offset) {
    var low = 0, high = offsets.length - 2;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (offsets[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low + 1;
  }
}

/// Presence, including explicit false and zero, determines inheritance.
Map<String, dynamic> resolveReaderSettings({
  Map<String, dynamic> app = const {},
  Map<String, dynamic> library = const {},
  Map<String, dynamic> title = const {},
}) => {
  'rtl': false,
  'mode': 'horizontal',
  'background': 'black',
  'fit': 'contain',
  'fontSize': 20.0,
  'lineHeight': 1.6,
  'coverSingle': true,
  'leadingEdgeAction': 'previous',
  'trailingEdgeAction': 'next',
  'topAction': 'toggleChrome',
  'centerAction': 'toggleChrome',
  for (final entry in app.entries)
    if (entry.value != null) entry.key: entry.value,
  for (final entry in library.entries)
    if (entry.value != null) entry.key: entry.value,
  for (final entry in title.entries)
    if (entry.value != null) entry.key: entry.value,
};

/// A passage is independent of viewport geometry. End offsets are exclusive;
/// the unit identifies the source text model rather than assuming pixel offsets.
class ReaderTextAnchor {
  const ReaderTextAnchor({
    required this.resourceId,
    required this.revision,
    required this.startKey,
    required this.startPage,
    required this.startOffset,
    required this.endKey,
    required this.endPage,
    required this.endOffset,
    required this.unit,
    required this.quote,
  });
  final String resourceId, revision, startKey, endKey, unit, quote;
  final int startPage, startOffset, endPage, endOffset;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'resource': resourceId,
    'revision': revision,
    'unit': unit,
    'start': {'key': startKey, 'page': startPage, 'offset': startOffset},
    'end': {'key': endKey, 'page': endPage, 'offset': endOffset},
    'quote': quote,
  };
  bool compatible(String resource, String contentRevision) =>
      resourceId == resource && revision == contentRevision;
  static ReaderTextAnchor? decode(Object? input) {
    try {
      if (input is! Map ||
          input['version'] != 1 ||
          input['resource'] is! String ||
          (input['resource'] as String).isEmpty ||
          (input['resource'] as String).length > 512 ||
          input['revision'] is! String ||
          (input['revision'] as String).length > 512 ||
          !{'domUtf16', 'pdfCharacter'}.contains(input['unit']) ||
          input['quote'] is! String ||
          (input['quote'] as String).length > 16000)
        return null;
      final start = input['start'], end = input['end'];
      bool endpoint(Object? value) =>
          value is Map &&
          value['key'] is String &&
          (value['key'] as String).isNotEmpty &&
          (value['key'] as String).length <= 1024 &&
          !(value['key'] as String).startsWith('/') &&
          !(value['key'] as String).contains('\\') &&
          !(value['key'] as String).split('/').contains('..') &&
          value['page'] is int &&
          value['page'] >= 1 &&
          value['page'] <= 100000 &&
          value['offset'] is int &&
          value['offset'] >= 0 &&
          value['offset'] <= 100000000;
      if (!endpoint(start) || !endpoint(end)) return null;
      if (input['unit'] == 'pdfCharacter' && end['offset'] == 0) return null;
      if (end['page'] < start['page'] ||
          end['page'] == start['page'] &&
              (end['key'] != start['key'] || end['offset'] <= start['offset']))
        return null;
      return ReaderTextAnchor(
        resourceId: input['resource'],
        revision: input['revision'],
        startKey: start['key'],
        startPage: start['page'],
        startOffset: start['offset'],
        endKey: end['key'],
        endPage: end['page'],
        endOffset: end['offset'],
        unit: input['unit'],
        quote: input['quote'],
      );
    } on Object {
      return null;
    }
  }
}

abstract final class ReaderTapPolicy {
  static const actions = {'previous', 'next', 'toggleChrome', 'study', 'none'};
  static String action(
    Offset point,
    Size viewport,
    Map<String, dynamic> options,
  ) {
    if (viewport.isEmpty) return 'none';
    final x = point.dx / viewport.width, y = point.dy / viewport.height;
    if (y < .2) return options['topAction'] as String? ?? 'toggleChrome';
    if (x >= .33 && x <= .67)
      return options['centerAction'] as String? ?? 'toggleChrome';
    final leading = options['rtl'] == true ? x > .67 : x < .33;
    return options[leading ? 'leadingEdgeAction' : 'trailingEdgeAction']
            as String? ??
        (leading ? 'previous' : 'next');
  }
}
