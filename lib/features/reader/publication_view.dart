import '../../domain/reader/reader_contract.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/reader/book_page_source.dart';
import '../../data/reader/publication_server.dart';

/// Metrics are scoped to the resource revision, page and current load generation.
class PublicationView extends StatefulWidget {
  const PublicationView({
    super.key,
    required this.source,
    required this.page,
    required this.revision,
    required this.geometry,
    required this.fit,
    required this.fontSize,
    required this.lineHeight,
    required this.onPosition,
    required this.onSelection,
    this.initialY = 0,
    this.initialSelection,
    this.onTap,
  });
  final ArchiveBookSource source;
  final int page;
  final String revision, fit;
  final Size geometry;
  final double fontSize, lineHeight, initialY;
  final void Function(double x, double y) onPosition;
  final void Function(String text, int offset, int end) onSelection;
  final ReaderTextAnchor? initialSelection;
  final ValueChanged<Offset>? onTap;
  @override
  State<PublicationView> createState() => _PublicationViewState();
}

class _PublicationViewState extends State<PublicationView> {
  WebViewController? _controller;
  String _request = const Uuid().v4();
  int _attempts = 0;
  Timer? _timeout;
  String? _error;
  int _sequence = 0;
  bool _ready = false, _restored = false;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    _timeout?.cancel();
    final previous = _controller;
    _controller = null;
    if (previous != null)
      unawaited(
        previous
            .loadHtmlString('<html><body></body></html>')
            .catchError((Object _) {}),
      );
    _request = const Uuid().v4();
    _sequence = 0;
    _ready = false;
    _restored = false;
    _attempts++;
    if (mounted) setState(() => _error = null);
    if (!Platform.isMacOS && !Platform.isIOS && !Platform.isAndroid) {
      setState(
        () => _error =
            'This platform does not yet have the publication renderer. The publication and its reading state remain in your library.',
      );
      return;
    }
    try {
      final server = await widget.source.publicationServer();
      if (!mounted) return;
      final uri = server.page(
        widget.source.locator(widget.page),
        requestId: _request,
        revision: widget.revision,
        reflowable: widget.source.reflowable,
        fontSize: widget.fontSize,
        lineHeight: widget.lineHeight,
        fit: widget.fit,
        width: widget.geometry.width,
        height: widget.geometry.height,
      );
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel(
        'TangerineReader',
        onMessageReceived: (message) => _metrics(message.message),
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            return target != null &&
                    server.contains(target) &&
                    target.path == uri.path &&
                    target.query == uri.query
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted)
              setState(
                () =>
                    _error = 'Publication failed to load: ${error.description}',
              );
          },
        ),
      );
      if (!mounted) return;
      _controller = controller;
      setState(() {});
      await controller.loadRequest(uri);
      _timeout = Timer(const Duration(seconds: 12), () {
        if (mounted && !_ready)
          setState(
            () => _error =
                'Publication readiness timed out. Reopen this page to retry.',
          );
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Publication could not open: $error');
    }
  }

  void _metrics(String raw) {
    if (!mounted || raw.length > 32000) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map ||
          data['version'] != 1 ||
          data['request'] != _request ||
          data['revision'] != widget.revision ||
          data['pageKey'] != widget.source.locator(widget.page) ||
          data['sequence'] is! int ||
          data['sequence'] <= _sequence)
        return;
      _sequence = data['sequence'];
      if (data['kind'] == 'error') {
        setState(
          () => _error =
              data['message'] as String? ?? 'Publication measurement failed',
        );
        return;
      }
      if (data['kind'] == 'tap') {
        final x = data['x'], y = data['y'];
        if (x is num &&
            y is num &&
            x.isFinite &&
            y.isFinite &&
            x >= 0 &&
            x <= 1 &&
            y >= 0 &&
            y <= 1)
          widget.onTap?.call(Offset(x.toDouble(), y.toDouble()));
        return;
      }
      if (data['kind'] == 'anchorError') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] as String? ??
                  'The saved passage could not be restored.',
            ),
          ),
        );
        return;
      }
      if (data['kind'] == 'selection') {
        if (data['text'] == '' && data['offset'] == 0 && data['end'] == 0) {
          widget.onSelection('', 0, 0);
          return;
        }
        if (data['text'] is String &&
            data['offset'] is int &&
            data['offset'] >= 0 &&
            data['end'] is int &&
            data['end'] > data['offset'] &&
            data['end'] <= 100000000 &&
            (data['text'] as String).length <= 16000)
          widget.onSelection(data['text'], data['offset'], data['end']);
        return;
      }
      if (data['kind'] != 'metrics' || data['ready'] != true) return;
      for (final key in [
        'width',
        'height',
        'scaledWidth',
        'scaledHeight',
        'viewportWidth',
        'viewportHeight',
        'scale',
      ]) {
        final value = data[key];
        final maximum =
            widget.source.reflowable && {'height', 'scaledHeight'}.contains(key)
            ? 10000000
            : 120000;
        if (value is! num || !value.isFinite || value <= 0 || value > maximum)
          throw const FormatException('Invalid metrics');
      }
      if (!widget.source.reflowable &&
          (data['width'] as num) * (data['height'] as num) > 80000000)
        throw const FormatException('Publication exceeds geometry limit');
      _timeout?.cancel();
      if (!_ready) setState(() => _ready = true);
      if (!_restored) {
        _restored = true;
        final selection = widget.initialSelection;
        if (selection != null) {
          final args = jsonEncode({
            'request': _request,
            'revision': widget.revision,
            'pageKey': widget.source.locator(widget.page),
            'start': selection.startOffset,
            'end': selection.endOffset,
            'quote': selection.quote,
          });
          unawaited(
            _controller!.runJavaScript(
              'window.tangerineRestoreText && window.tangerineRestoreText($args);',
            ),
          );
        } else if (widget.initialY > 0)
          unawaited(
            _controller!.runJavaScript(
              'window.scrollTo(0,${widget.initialY.clamp(0, 1)}*document.body.scrollHeight);',
            ),
          );
      } else {
        final x = data['x'], y = data['y'];
        if (x is num && y is num && x.isFinite && y.isFinite)
          widget.onPosition(x.toDouble().clamp(0, 1), y.toDouble().clamp(0, 1));
      }
    } catch (_) {
      setState(() => _error = 'The publication returned invalid page metrics.');
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    final controller = _controller;
    if (controller != null)
      unawaited(controller.loadHtmlString('<html><body></body></html>'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null)
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)),
      );
    if (_controller == null)
      return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        Positioned.fill(
          child: WebViewWidget(
            key: ValueKey(_request),
            controller: _controller!,
          ),
        ),
        if (!_ready)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
