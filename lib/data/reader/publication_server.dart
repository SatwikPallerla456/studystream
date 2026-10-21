import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import 'safe_book_archive.dart';

/// A publication-only loopback origin. It never serves host filesystem paths.
/// Package scripts, event handlers, external navigation and network resources
/// are blocked; only the request-scoped metrics bridge can execute.
class PublicationServer {
  PublicationServer._(this.archive, this._server, this._token);
  final SafeBookArchive archive;
  final HttpServer _server;
  final String _token;
  int _active = 0;
  bool _closed = false;
  static Future<PublicationServer> open(SafeBookArchive archive) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    final result = PublicationServer._(archive, server, const Uuid().v4());
    server.listen(
      (request) => unawaited(result._serve(request).catchError((Object _) {})),
    );
    return result;
  }

  Uri page(
    String path, {
    required String requestId,
    required String revision,
    required bool reflowable,
    required double fontSize,
    required double lineHeight,
    required String fit,
    required double width,
    required double height,
  }) => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: _server.port,
    path: '/${_token}/${resolve('', path)}',
    queryParameters: {
      'request': requestId,
      'revision': revision,
      'flow': '$reflowable',
      'font': '$fontSize',
      'line': '$lineHeight',
      'fit': fit,
      'width': '$width',
      'height': '$height',
    },
  );
  bool contains(Uri uri) =>
      uri.scheme == 'http' &&
      uri.host == '127.0.0.1' &&
      uri.port == _server.port &&
      uri.path.startsWith('/$_token/');
  static String resolve(String from, String href) {
    final uri = Uri.parse(href);
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.path.startsWith('/') ||
        uri.path.contains('\\'))
      throw const FormatException('External publication resource');
    final path = p.posix.normalize(
      p.posix.join(
        p.posix.dirname(from.isEmpty ? 'root.xhtml' : from),
        Uri.decodeComponent(uri.path),
      ),
    );
    return SafeBookArchive.normalizeName(path);
  }

  static String _mime(String path) =>
      switch (p.posix.extension(path).toLowerCase()) {
        '.css' => 'text/css',
        '.svg' => 'image/svg+xml',
        '.png' => 'image/png',
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        '.woff' => 'font/woff',
        '.woff2' => 'font/woff2',
        '.ttf' => 'font/ttf',
        '.otf' => 'font/otf',
        '.xhtml' || '.html' || '.htm' => 'text/html; charset=utf-8',
        _ => 'application/octet-stream',
      };
  Future<void> _serve(HttpRequest request) async {
    if (_closed ||
        !{'GET', 'HEAD'}.contains(request.method) ||
        !request.uri.path.startsWith('/$_token/') ||
        _active >= 4) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    _active++;
    try {
      final name = SafeBookArchive.normalizeName(
        Uri.decodeComponent(request.uri.path.substring(_token.length + 2)),
      );
      var mime = _mime(name);
      final svgPage =
          mime == 'image/svg+xml' &&
          request.uri.queryParameters['request'] != null;
      if (svgPage) mime = 'text/html; charset=utf-8';
      final nonce = base64UrlEncode(
        List<int>.generate(24, (_) => Random.secure().nextInt(256)),
      );
      request.response.headers.set('Content-Type', mime);
      request.response.headers.set('X-Content-Type-Options', 'nosniff');
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.headers.set('Referrer-Policy', 'no-referrer');
      request.response.headers.set(
        'Content-Security-Policy',
        "default-src 'none'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; font-src 'self'; script-src 'nonce-$nonce'; connect-src 'none'; media-src 'none'; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'",
      );
      final bytes = await archive.read(name, limit: 32 * 1024 * 1024);
      if (request.method == 'HEAD') {
        request.response.contentLength = bytes.length;
        return;
      }
      if (mime.startsWith('text/html') || mime == 'image/svg+xml') {
        var xml = XmlDocument.parse(utf8.decode(bytes));
        if (svgPage)
          xml = XmlDocument.parse(
            '<html><head></head><body>${xml.rootElement.toXmlString()}</body></html>',
          );
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
            if ({'src', 'href', 'poster', 'action'}.contains(attr.name.local)) {
              final value = attr.value.trim();
              if (value.startsWith('#')) continue;
              if (Uri.tryParse(value)?.hasScheme != false ||
                  value.startsWith('//') ||
                  value.startsWith('/'))
                node.attributes.remove(attr);
            }
          }
        }
        if (mime.startsWith('text/html')) {
          final head = xml.descendants
              .whereType<XmlElement>()
              .where((n) => n.name.local == 'head')
              .firstOrNull;
          final body = xml.descendants
              .whereType<XmlElement>()
              .where((n) => n.name.local == 'body')
              .firstOrNull;
          if (head == null || body == null)
            throw const FormatException(
              'Publication HTML requires head and body',
            );
          final declaredViewport = head.children
              .whereType<XmlElement>()
              .where(
                (node) =>
                    node.name.local == 'meta' &&
                    node.getAttribute('name') == 'viewport',
              )
              .map((node) => node.getAttribute('content') ?? '')
              .join(',');
          for (final viewport
              in head.children
                  .whereType<XmlElement>()
                  .where(
                    (n) =>
                        n.name.local == 'meta' &&
                        n.getAttribute('name') == 'viewport',
                  )
                  .toList()) {
            head.children.remove(viewport);
          }
          head.children.add(
            XmlElement(XmlName('meta'), [
              XmlAttribute(XmlName('name'), 'viewport'),
              XmlAttribute(
                XmlName('content'),
                'width=device-width,initial-scale=1,maximum-scale=5',
              ),
            ]),
          );
          final id = request.uri.queryParameters['request'] ?? '';
          if (id.isEmpty || id.length > 128)
            throw const FormatException('Publication request identity missing');
          final bridge = _bridge({
            ...request.uri.queryParameters,
            'declared':
                RegExp(r'width\s*=\s*\d+').hasMatch(declaredViewport) &&
                    RegExp(r'height\s*=\s*\d+').hasMatch(declaredViewport)
                ? 'true'
                : 'false',
          }, name);
          body.children.add(
            XmlElement(
              XmlName('script'),
              [XmlAttribute(XmlName('nonce'), nonce)],
              [XmlText(bridge)],
            ),
          );
        }
        // HTML parser must receive literal script content, not XML-escaped text.
        var output = xml.toXmlString();
        if (mime.startsWith('text/html')) {
          output = output.replaceAllMapped(
            RegExp(r'(<script[^>]*>)([\s\S]*?)(</script>)'),
            (match) =>
                '${match[1]}${match[2]!.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&')}${match[3]}',
          );
        }
        request.response.write(output);
      } else {
        request.response.add(bytes);
      }
    } catch (_) {
      request.response.statusCode = HttpStatus.unprocessableEntity;
    } finally {
      _active--;
      await request.response.close();
    }
  }

  String _bridge(Map<String, String> args, String pageKey) {
    final scope =
        jsonEncode({
              'version': 1,
              'request': args['request'],
              'revision': args['revision'],
              'pageKey': pageKey,
            })
            .replaceAll('<', r'\u003c')
            .replaceAll('>', r'\u003e')
            .replaceAll('&', r'\u0026');
    final flow = args['flow'] == 'true';
    final fit = {'contain', 'fitWidth', 'fill'}.contains(args['fit'])
        ? args['fit']
        : 'contain';
    double dimension(String key, double fallback) {
      final v = double.tryParse(args[key] ?? '');
      return v != null && v.isFinite && v >= 1 && v <= 24000 ? v : fallback;
    }

    final width = dimension('width', 800), height = dimension('height', 1100);
    final font = dimension('font', 20).clamp(12, 36),
        line = dimension('line', 1.6).clamp(1.2, 2.4);
    return '''(()=>{'use strict';const scope=$scope;let sequence=0,ready=false,timer;
const flow=$flow,declared=${args['declared'] == 'true'},sourceWidth=$width,sourceHeight=$height;
const post=(data)=>{if(window.TangerineReader)TangerineReader.postMessage(JSON.stringify({...scope,sequence:++sequence,...data}));};
const authorSize={width:false,height:false};let ruleCount=0;
const inspect=(rules)=>{for(const rule of rules){if(++ruleCount>2000)return;if(rule.cssRules)inspect(rule.cssRules);if(!rule.selectorText||!rule.style)continue;try{if(document.body.matches(rule.selectorText)){if(rule.style.width)authorSize.width=true;if(rule.style.height)authorSize.height=true;}}catch(_){}}};
const measure=()=>{
 const root=document.documentElement,body=document.body;
 if(!flow && !ready)return;
 if(!flow && !body.dataset.tangerineMeasured){for(const sheet of document.styleSheets){try{inspect(sheet.cssRules);}catch(_){}}body.dataset.tangerineMeasured='1';}
 const computed=getComputedStyle(body);
 let width=flow?Math.max(body.scrollWidth,1):declared?sourceWidth:authorSize.width?parseFloat(computed.width):sourceWidth,height=flow?Math.max(body.scrollHeight,1):declared?sourceHeight:authorSize.height?parseFloat(computed.height):sourceHeight;
 if(!Number.isFinite(width)||!Number.isFinite(height)||width<1||height<1||width>24000||height>(flow?10000000:24000)||(!flow&&width*height>80000000)){post({kind:'error',message:'Publication geometry exceeds limits'});return;}
 let scale=1;
 if(!flow){scale=${jsonEncode(fit)}==='fitWidth'?innerWidth/width:${jsonEncode(fit)}==='fill'?Math.max(innerWidth/width,innerHeight/height):Math.min(innerWidth/width,innerHeight/height);
 body.style.width=width+'px';body.style.height=height+'px';body.style.transformOrigin='0 0';body.style.transform='scale('+scale+')';root.style.overflow='hidden';}
 post({kind:'metrics',ready,width,height,scaledWidth:width*scale,scaledHeight:height*scale,scale,viewportWidth:innerWidth,viewportHeight:innerHeight,x:scrollX/width,y:scrollY/height});
};
if(flow){document.body.style.fontSize='${font}px';document.body.style.lineHeight='$line';}
const images=Array.from(document.images).map(image=>image.complete?Promise.resolve():new Promise((resolve)=>{image.onload=resolve;image.onerror=resolve;}));
Promise.race([Promise.all([document.fonts?document.fonts.ready:Promise.resolve(),...images]),new Promise((_,reject)=>setTimeout(()=>reject(new Error('Assets did not become ready within 8 seconds')),8000))])
 .then(()=>requestAnimationFrame(()=>requestAnimationFrame(()=>{ready=true;measure();}))).catch(error=>post({kind:'error',message:error.message}));
addEventListener('resize',()=>{clearTimeout(timer);timer=setTimeout(measure,80);});
if(window.ResizeObserver){const observer=new ResizeObserver(()=>{clearTimeout(timer);timer=setTimeout(measure,80);});observer.observe(document.body);}
addEventListener('scroll',()=>{clearTimeout(timer);timer=setTimeout(measure,700);},{passive:true});
let tapTimer;
document.addEventListener('click',(event)=>{clearTimeout(tapTimer);if(window.visualViewport&&window.visualViewport.scale>1.05)return;const selection=getSelection();if(event.target.closest&&event.target.closest('a,button,input,textarea,select')||selection&&!selection.isCollapsed)return;const x=event.clientX/innerWidth,y=event.clientY/innerHeight;tapTimer=setTimeout(()=>post({kind:'tap',x,y}),500);});
document.addEventListener('dblclick',()=>clearTimeout(tapTimer));
const textNodes=(root)=>{const nodes=[],walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let node;while(node=walker.nextNode()){if(node.parentElement&&node.parentElement.closest('script,style,noscript'))continue;nodes.push(node);if(nodes.length>250000)throw new Error('Publication text exceeds limits');}return nodes;};
const offsetAt=(container,offset)=>{const prefix=document.createRange();prefix.selectNodeContents(document.body);prefix.setEnd(container,offset);return textNodes(prefix.cloneContents()).reduce((sum,node)=>sum+node.data.length,0);};
let selectionTimer;
document.addEventListener('selectionchange',()=>{clearTimeout(selectionTimer);selectionTimer=setTimeout(()=>{try{const s=getSelection();if(!s||s.rangeCount===0||s.isCollapsed){post({kind:'selection',text:'',offset:0,end:0});return;}const range=s.getRangeAt(0),start=offsetAt(range.startContainer,range.startOffset),end=offsetAt(range.endContainer,range.endOffset);if(end>100000000)return;post({kind:'selection',text:s.toString().slice(0,16000),offset:start,end});}catch(error){post({kind:'error',message:error.message});}},160);});
window.tangerineRestoreText=(args)=>{if(args.request!==scope.request||args.revision!==scope.revision||args.pageKey!==scope.pageKey||!Number.isInteger(args.start)||!Number.isInteger(args.end)||args.start<0||args.end<=args.start)return;try{const nodes=textNodes(document.body);let count=0,start=null,end=null;for(const node of nodes){const next=count+node.data.length;if(!start&&args.start<next)start=[node,args.start-count];if(args.end<=next){end=[node,args.end-count];break;}count=next;}if(!start||!end)throw new Error('Saved passage offsets are unavailable');const range=document.createRange();range.setStart(...start);range.setEnd(...end);if(args.quote&&!range.toString().startsWith(args.quote))throw new Error('Saved passage text changed');const selection=getSelection();selection.removeAllRanges();selection.addRange(range);const rect=range.getBoundingClientRect();scrollTo(0,scrollY+rect.top-innerHeight*.3);measure();}catch(error){post({kind:'anchorError',message:error.message});}};
})();''';
  }

  Future<void> dispose() async {
    _closed = true;
    await _server.close(force: true);
  }
}
