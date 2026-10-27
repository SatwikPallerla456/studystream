import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/playback/playback_engine.dart';

class VideoSubtitleCue {
  const VideoSubtitleCue(this.start, this.end, this.text);
  final int start, end;
  final String text;
}

class VideoSubtitleDocument {
  VideoSubtitleDocument(List<VideoSubtitleCue> rows)
    : cues = List.of(rows)..sort((a, b) => a.start.compareTo(b.start)) {
    var maximum = 0;
    for (final cue in cues) {
      if (cue.end > maximum) maximum = cue.end;
      _ends.add(maximum);
    }
  }
  final List<VideoSubtitleCue> cues;
  final _ends = <int>[];
  static Future<VideoSubtitleDocument> open(String path) async {
    final file = File(path);
    if (await file.length() > 2 * 1024 * 1024)
      throw const FormatException('Choose subtitles smaller than 2 MiB.');
    return parse(await file.readAsString());
  }

  static VideoSubtitleDocument parse(String text) {
    if (utf8.encode(text).length > 2 * 1024 * 1024)
      throw const FormatException('Subtitle file exceeds 2 MiB.');
    int? stamp(String value) {
      final match = RegExp(
        r'^(?:(\d{1,3}):)?(\d{2}):(\d{2})[.,](\d{3})$',
      ).firstMatch(value);
      if (match == null) return null;
      final parts = [
        for (var i = 1; i <= 4; i++) int.parse(match.group(i) ?? '0'),
      ];
      if (parts[1] > 59 || parts[2] > 59) return null;
      return ((parts[0] * 60 + parts[1]) * 60 + parts[2]) * 1000 + parts[3];
    }

    final rows = <VideoSubtitleCue>[];
    for (final block
        in text
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split(RegExp(r'\n[ \t]*\n'))) {
      final lines = block.split('\n');
      final index = lines.indexWhere((l) => l.contains('-->'));
      if (index < 0 || index + 1 >= lines.length) continue;
      final times = lines[index].trim().split(RegExp(r'\s+-->\s+'));
      if (times.length != 2) continue;
      final start = stamp(times.first),
          end = stamp(times.last.split(RegExp(r'\s+')).first);
      final body = lines
          .skip(index + 1)
          .join('\n')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&nbsp;', ' ');
      if (start == null || end == null || end <= start || body.trim().isEmpty)
        continue;
      if (body.length > 4000 || rows.length >= 4000)
        throw const FormatException(
          'Subtitles exceed 4,000 cues or 4,000 characters per cue.',
        );
      rows.add(VideoSubtitleCue(start, end, body));
    }
    if (rows.isEmpty)
      throw const FormatException('No timed SRT/WebVTT cues were found.');
    return VideoSubtitleDocument(rows);
  }

  String textAt(int position) {
    var low = 0, high = cues.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (cues[mid].start <= position) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final visible = <String>[];
    for (
      var i = low - 1;
      i >= 0 && _ends[i] > position && visible.length < 4;
      i--
    ) {
      if (cues[i].end > position) visible.insert(0, cues[i].text);
    }
    return visible.join('\n');
  }

  String srt() {
    String time(int ms) =>
        '${(ms ~/ 3600000).toString().padLeft(2, '0')}:${(ms ~/ 60000 % 60).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')},${(ms % 1000).toString().padLeft(3, '0')}';
    return [
      for (var i = 0; i < cues.length; i++)
        '${i + 1}\n${time(cues[i].start)} --> ${time(cues[i].end)}\n${cues[i].text}\n',
    ].join('\n');
  }
}

class VideoSubtitlePresentation extends ChangeNotifier {
  VideoSubtitleDocument? primary, secondary;
  double size = 24, secondarySize = 22, background = .65, bottom = 28;
  int color = 0xffffffff, secondaryColor = 0xffffe082;
  int delay = 0, secondaryDelay = 0;
  bool enabled = true;
  void changed() => notifyListeners();
}

class VideoSubtitleLayer extends StatelessWidget {
  const VideoSubtitleLayer({
    super.key,
    required this.player,
    required this.presentation,
    required this.child,
  });
  final PlaybackEngine player;
  final VideoSubtitlePresentation presentation;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      IgnorePointer(
        child: ListenableBuilder(
          listenable: presentation,
          builder: (context, _) => StreamBuilder<Duration>(
            stream: player.stream.position,
            initialData: player.state.position,
            builder: (context, snapshot) {
              final time = (snapshot.data ?? Duration.zero).inMilliseconds;
              final p = presentation;
              final a = p.enabled
                  ? p.primary?.textAt(time - p.delay) ?? ''
                  : '';
              final b = p.enabled
                  ? p.secondary?.textAt(time - p.secondaryDelay) ?? ''
                  : '';
              Widget line(String text, double size, int color) => Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size,
                  color: Color(color),
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(
                      blurRadius: 3,
                      color: Colors.black,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              );
              return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, p.bottom),
                  child: a.isEmpty && b.isEmpty
                      ? const SizedBox.shrink()
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: p.background),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (a.isNotEmpty) line(a, p.size, p.color),
                                if (b.isNotEmpty)
                                  line(b, p.secondarySize, p.secondaryColor),
                              ],
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

/// Explicit, bounded text translation. Keys are supplied by secure UI storage.
class VideoSubtitleTranslator {
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  bool _closed = false;
  static Uri endpoint(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' &&
            !{'localhost', '127.0.0.1', '::1'}.contains(uri.host))) {
      throw const FormatException(
        'Use an HTTPS translation endpoint, or HTTP on localhost, without credentials or a query.',
      );
    }
    return uri;
  }

  Future<VideoSubtitleDocument> translate(
    VideoSubtitleDocument document, {
    required Uri url,
    required String source,
    required String target,
    String key = '',
    required void Function(int, int) progress,
  }) async {
    if (document.cues.length > 4000)
      throw const FormatException(
        'Translate at most 4,000 cues at a time. Use a shorter subtitle excerpt.',
      );
    if (!RegExp(r'^[a-zA-Z-]{2,16}$').hasMatch(source) ||
        !RegExp(r'^[a-zA-Z-]{2,16}$').hasMatch(target)) {
      throw const FormatException(
        'Use language codes such as auto, en, es or pt-BR.',
      );
    }
    final translated = <VideoSubtitleCue>[];
    for (var offset = 0; offset < document.cues.length;) {
      if (_closed) throw StateError('Translation cancelled');
      final batch = <VideoSubtitleCue>[];
      var size = 0;
      while (offset + batch.length < document.cues.length &&
          batch.length < 20) {
        final cue = document.cues[offset + batch.length];
        if (batch.isNotEmpty && size + cue.text.length > 8000) break;
        size += cue.text.length;
        batch.add(cue);
      }
      final request = await _http
          .postUrl(url)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'q': batch.map((c) => c.text).toList(),
          'source': source,
          'target': target,
          'format': 'text',
          if (key.isNotEmpty) 'api_key': key,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        await response.drain<void>().timeout(const Duration(seconds: 5));
        throw HttpException(
          'Translation returned HTTP ${response.statusCode}. Check the service, language codes and key.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024)
          throw const FormatException('Translation response exceeds 1 MiB.');
      }
      final value = (jsonDecode(utf8.decode(bytes)) as Map)['translatedText'];
      if (value is! List ||
          value.length != batch.length ||
          value.any((v) => v is! String || v.length > 8000)) {
        throw const FormatException(
          'The service returned an invalid batch translation.',
        );
      }
      for (var i = 0; i < batch.length; i++)
        translated.add(
          VideoSubtitleCue(batch[i].start, batch[i].end, value[i] as String),
        );
      offset += batch.length;
      progress(offset, document.cues.length);
    }
    return VideoSubtitleDocument(translated);
  }

  void close() {
    _closed = true;
    _http.close(force: true);
  }
}
