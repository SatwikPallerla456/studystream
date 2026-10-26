import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview_forge/flutter_inappwebview_forge.dart';
import 'package:uuid/uuid.dart';

import '../../domain/reader/reader_contract.dart';
import '../../domain/reader/reader_jobs.dart';
import '../../data/reader/book_page_source.dart';
import '../../data/reader/publication_server.dart';

/// Owned by the screen; detaching a page makes old native callbacks inert.
class PublicationHandle {
  Future<void> Function()? _capture;
  Future<void> capture() async => await _capture?.call();
}

InAppWebViewSettings publicationWebSettings() => InAppWebViewSettings(
  javaScriptEnabled: true,
  useShouldOverrideUrlLoading: true,
  supportMultipleWindows: false,
  javaScriptCanOpenWindowsAutomatically: false,
  mediaPlaybackRequiresUserGesture: true,
  allowFileAccessFromFileURLs: false,
  allowUniversalAccessFromFileURLs: false,
  disableContextMenu: false,
  transparentBackground: false,
);

/// Native HTML/CSS renderer: WKWebView, Android WebView, WebView2 and WPE WebKit.
/// Readiness and messages belong to one request/revision/canonical page.
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
    required this.jobs,
    required this.onTextPosition,
    required this.onGeometry,
    required this.onLink,
    required this.onChooseSection,
    this.handle,
    this.initialY = 0,
    this.initialSelection,
    this.initialTextOffset,
    this.initialTextQuote,
    this.initialTextBias = .2,
    this.fragment,
    this.onTap,
  });
  final ArchiveBookSource source;
  final int page;
  final String revision, fit;
  final Size geometry;
  final double fontSize, lineHeight, initialY, initialTextBias;
  final ReaderJobScheduler jobs;
  final PublicationHandle? handle;
  final int? initialTextOffset;
  final String? initialTextQuote, fragment;
  final void Function(double x, double y) onPosition;
  final void Function(int offset, String quote, double bias) onTextPosition;
  final ValueChanged<Size> onGeometry;
  final ValueChanged<String> onLink;
  final VoidCallback onChooseSection;
  final void Function(String text, int offset, int end) onSelection;
  final ReaderTextAnchor? initialSelection;
  final ValueChanged<Offset>? onTap;
  @override
  State<PublicationView> createState() => _PublicationViewState();
}

class _PublicationViewState extends State<PublicationView> {
  InAppWebViewController? _controller;
  PublicationServer? _server;
  Uri? _uri;
  String _request = '';
  int _attempts = 0, _sequence = 0;
  ReaderLease<void>? _lease;
  Completer<void>? _readiness;
  Timer? _timeout;
  String? _error;
  bool _ready = false, _restored = false;
  late final Future<void> Function() _captureCallback = _capture;
  @override
  void initState() {
    super.initState();
    widget.handle?._capture = _captureCallback;
    unawaited(_open());
  }

  Future<void> _open() async {
    if (_attempts >= 3) return;
    _timeout?.cancel();
    _lease?.release();
    _controller = null;
    _uri = null;
    _request = const Uuid().v4();
    final request = _request;
    _sequence = 0;
    _ready = false;
    _restored = false;
    _attempts++;
    setState(() => _error = null);
    final lease = widget.jobs.request<void>(
      key:
          'publication:${widget.revision}:${widget.source.locator(widget.page)}:$request',
      priority: ReaderPriority.visible,
      estimatedBytes: 32 * 1024 * 1024,
      run: (token) async {
        if (Platform.isWindows) {
          final version = await WebViewEnvironment.getAvailableVersion();
          if (version == null || version.isEmpty)
            throw StateError(
              'Install the Microsoft Edge WebView2 Runtime, then reopen this book.',
            );
        }
        final server = await widget.source.publicationServer();
        token.check();
        final intrinsic = await widget.source.geometry(
          widget.page,
          cancellation: token,
        );
        token.check();
        if (!mounted || request != _request) throw const ReaderCancelled();
        final ready = Completer<void>();
        _readiness = ready;
        token.onCancel(() {
          if (!ready.isCompleted) ready.completeError(const ReaderCancelled());
        });
        _server = server;
        _uri = server.page(
          widget.source.locator(widget.page),
          requestId: request,
          revision: widget.revision,
          reflowable: widget.source.reflowable,
          fontSize: widget.fontSize,
          lineHeight: widget.lineHeight,
          fit: widget.fit,
          width: intrinsic.width,
          height: intrinsic.height,
        );
        setState(() {});
        _timeout = Timer(
          const Duration(seconds: 15),
          () => _fail(
            'This section did not become ready in 15 seconds. Retry, or choose another section.',
          ),
        );
        await ready.future;
        token.check();
      },
    );
    _lease = lease;
    try {
      await lease.future;
    } on ReaderCancelled {
      /* Ownership ended; stale messages cannot commit. */
    } catch (error) {
      if (mounted && request == _request)
        _fail('Publication could not open: $error');
    } finally {
      lease.release();
      if (identical(_lease, lease)) _lease = null;
    }
  }

  void _fail(String message) {
    if (!mounted || _error != null) return;
    _timeout?.cancel();
    final readiness = _readiness;
    if (readiness != null && !readiness.isCompleted)
      readiness.completeError(StateError(message));
    // Removing the platform view releases the failed native surface before retry.
    setState(() {
      _error = message;
      _uri = null;
      _controller = null;
    });
  }

  Future<dynamic> _js(String script) async {
    try {
      return await _controller?.evaluateJavascript(source: script);
    } catch (_) {
      return null;
    }
  }

  Future<void> _capture() async {
    if (!_ready || !_restored || _error != null) return;
    final request = _request;
    try {
      final packet = await _js(
        'window.tangerineCapturePosition && window.tangerineCapturePosition();',
      ).timeout(const Duration(milliseconds: 900));
      if (mounted && request == _request && packet is String) _message(packet);
    } on TimeoutException {
      /* Last delivered scroll anchor remains durable. */
    }
  }

  Future<void> _restore() async {
    final request = _request;
    final selection = widget.initialSelection;
    final start = selection?.startOffset ?? widget.initialTextOffset;
    dynamic restored;
    if (widget.fragment?.isNotEmpty == true) {
      restored = await _js(
        'window.tangerineFragment(${jsonEncode(widget.fragment)});',
      );
    } else if (start != null) {
      final args = jsonEncode({
        'request': request,
        'revision': widget.revision,
        'pageKey': widget.source.locator(widget.page),
        'start': start,
        'end': selection?.endOffset ?? start + 1,
        'quote': selection?.quote ?? widget.initialTextQuote,
        'bias': widget.initialTextBias,
        'select': selection != null,
      });
      restored = await _js('window.tangerineRestoreText($args);');
    }
    if (restored != true && widget.initialY > 0) {
      await _js(
        'window.scrollTo(0,${widget.initialY.clamp(0, 1)}*document.body.scrollHeight);',
      );
    }
    if (!mounted || request != _request) return;
    _restored = true;
    await _js('window.tangerineActivate();');
  }

  void _message(String raw) {
    if (!mounted || raw.length > 32000 || _error != null) return;
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
      switch (data['kind']) {
        case 'error':
          _fail(
            data['message'] is String
                ? data['message']
                : 'Publication measurement failed',
          );
          return;
        case 'link':
          if (data['href'] is String && (data['href'] as String).length < 2048)
            widget.onLink(data['href']);
          return;
        case 'anchorError':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] as String? ??
                    'The saved passage could not be restored.',
              ),
            ),
          );
          return;
        case 'tap':
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
        case 'position':
          final offset = data['offset'],
              quote = data['quote'],
              bias = data['bias'];
          if (_restored &&
              offset is int &&
              offset >= 0 &&
              offset <= 8000000 &&
              quote is String &&
              quote.length <= 120 &&
              bias is num &&
              bias.isFinite)
            widget.onTextPosition(offset, quote, bias.toDouble().clamp(0, 1));
          return;
        case 'selection':
          if (data['text'] == '' && data['offset'] == 0 && data['end'] == 0) {
            widget.onSelection('', 0, 0);
            return;
          }
          if (data['text'] is String &&
              data['offset'] is int &&
              data['offset'] >= 0 &&
              data['end'] is int &&
              data['end'] > data['offset'] &&
              data['end'] <= 8000000 &&
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
      final size = Size(
        (data['width'] as num).toDouble(),
        (data['height'] as num).toDouble(),
      );
      if (!widget.source.reflowable && size.width * size.height > 80000000)
        throw const FormatException('Publication exceeds geometry limit');
      // Flowing chapters scroll inside a bounded viewport, never a chapter-height surface.
      widget.onGeometry(
        widget.source.reflowable
            ? Size(
                (data['viewportWidth'] as num).toDouble(),
                (data['viewportHeight'] as num).toDouble(),
              )
            : size,
      );
      if (!_ready) {
        _timeout?.cancel();
        setState(() => _ready = true);
        if (_readiness?.isCompleted == false) _readiness!.complete();
        unawaited(_restore());
      } else if (_restored) {
        final x = data['x'], y = data['y'];
        if (x is num && y is num && x.isFinite && y.isFinite)
          widget.onPosition(x.toDouble().clamp(0, 1), y.toDouble().clamp(0, 1));
      }
    } catch (_) {
      _fail('The publication returned invalid page metrics.');
    }
  }

  @override
  void didUpdateWidget(covariant PublicationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      if (oldWidget.handle?._capture == _captureCallback)
        oldWidget.handle?._capture = null;
      widget.handle?._capture = _captureCallback;
    }
    if (oldWidget.geometry != widget.geometry && !widget.source.reflowable) {
      unawaited(
        _js(
          'window.tangerineSourceGeometry && window.tangerineSourceGeometry(${widget.geometry.width},${widget.geometry.height});',
        ),
      );
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    if (widget.handle?._capture == _captureCallback)
      widget.handle?._capture = null;
    _lease?.release();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              Text('Attempt $_attempts of 3'),
              if (_attempts < 3)
                FilledButton(
                  onPressed: () => unawaited(_open()),
                  child: const Text('Retry section'),
                ),
              TextButton(
                onPressed: widget.onChooseSection,
                child: const Text('Choose another section'),
              ),
              if (_attempts >= 3)
                const Text(
                  'Retry limit reached. Reopen the book after checking its file or the platform web renderer.',
                ),
            ],
          ),
        ),
      );
    final uri = _uri;
    if (uri == null) return const Center(child: CircularProgressIndicator());
    final request = _request;
    return Stack(
      children: [
        Positioned.fill(
          child: InAppWebView(
            key: ValueKey(request),
            initialSettings: publicationWebSettings(),
            initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
            onWebViewCreated: (controller) {
              if (request != _request || !mounted) return;
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: 'TangerineReader',
                callback: (List<dynamic> args) {
                  if (args.isNotEmpty && args.first is String)
                    _message(args.first);
                  return null;
                },
              );
            },
            onLoadStop: (controller, url) async {
              if (request == _request)
                await _js(
                  'window.tangerineMeasure && window.tangerineMeasure();',
                );
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final target = Uri.tryParse(action.request.url?.toString() ?? '');
              return target != null &&
                      _server!.contains(target) &&
                      target.path == uri.path &&
                      target.query == uri.query
                  ? NavigationActionPolicy.ALLOW
                  : NavigationActionPolicy.CANCEL;
            },
            onReceivedError: (controller, resource, error) {
              if (request == _request && resource.isForMainFrame == true)
                _fail('Publication failed to load: ${error.description}');
            },
            onReceivedHttpError: (controller, resource, response) {
              if (request == _request && resource.isForMainFrame == true)
                _fail(
                  'The publication section could not be read (${response.statusCode}).',
                );
            },
            onPermissionRequest: (controller, request) async =>
                PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.DENY,
                ),
            onCreateWindow: (controller, action) async => false,
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
