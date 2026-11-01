import 'dart:convert';
import 'dart:math' as math;
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart' as events;

class TimedTextSpan {
  const TimedTextSpan(this.from, this.to, this.start, this.end);
  final int from, to, start, end;
  bool active(int time) => time >= start && time < end;
}

class TimedTextCue {
  const TimedTextCue(this.start, this.end, this.text, {this.spans = const []});
  final int start;
  final int? end;
  final String text;
  final List<TimedTextSpan> spans;
}

/// Readable timed text, not a TTML layout/animation/image renderer.
abstract final class TimedText {
  static const maxTime = 7 * 24 * 60 * 60 * 1000;
  static bool isXml(String text) =>
      text.replaceFirst('\ufeff', '').trimLeft().startsWith('<');
  static bool isEnhancedPath(String path) => RegExp(
    r'\.(ttml|dfxp|xml|elrc|lrc)$',
    caseSensitive: false,
  ).hasMatch(path);
  static List<TimedTextCue> parse(
    String text, {
    int maxBytes = 2 * 1024 * 1024,
  }) {
    if (utf8.encode(text).length > maxBytes)
      throw FormatException('Timed text exceeds $maxBytes bytes.');
    return isXml(text) ? _ttml(text) : _lrc(text);
  }

  static int _bounded(num value) {
    if (!value.isFinite || value < 0 || value > maxTime)
      throw const FormatException(
        'Timed text contains a timestamp outside the supported seven-day timeline.',
      );
    return value.round();
  }

  static List<TimedTextCue> _lrc(String raw) {
    final lines = const LineSplitter().convert(raw.replaceFirst('\ufeff', ''));
    var offset = 0;
    for (final line in lines) {
      final match = RegExp(
        r'^\s*\[offset:([+-]?\d+)\]',
        caseSensitive: false,
      ).firstMatch(line);
      if (match != null) offset = int.parse(match[1]!).clamp(-60000, 60000);
    }
    int stamp(Match match, [int shift = 0]) {
      final seconds = int.parse(match[2]!);
      if (seconds > 59) throw const FormatException('Invalid lyric timestamp.');
      final time =
          int.parse(match[1]!) * 60000 +
          seconds * 1000 +
          int.parse((match[3] ?? '').padRight(3, '0')) +
          shift -
          offset;
      return _bounded(math.max(0, time));
    }

    const clock = r'(\d{1,5}):(\d{2})(?:[.:](\d{1,3}))?';
    final leading = RegExp('^\\s*\\[$clock\\]');
    final word = RegExp('[<\\[]$clock[>\\]]');
    final rows = <TimedTextCue>[];
    var totalSpans = 0;
    for (var line in lines) {
      final repeats = <int>[];
      while (true) {
        final tag = leading.firstMatch(line);
        if (tag == null) break;
        repeats.add(stamp(tag, offset));
        line = line.substring(tag.end);
      }
      if (repeats.isEmpty) continue;
      final tags = word.allMatches(line).toList();
      for (final sourceStart in repeats) {
        final start = _bounded(math.max(0, sourceStart - offset));
        final delta = sourceStart - repeats.first;
        final spans = <TimedTextSpan>[];
        final text = StringBuffer();
        int? end;
        if (tags.isEmpty) {
          text.write(line.trim());
        } else {
          final prefix = line.substring(0, tags.first.start).trimLeft();
          text.write(prefix);
          if (prefix.isNotEmpty)
            spans.add(
              TimedTextSpan(0, prefix.length, start, stamp(tags.first, delta)),
            );
          var previous = start;
          for (var i = 0; i < tags.length; i++) {
            final begin = stamp(tags[i], delta);
            if (begin < previous)
              throw const FormatException(
                'Enhanced lyric word timestamps must be in order.',
              );
            previous = begin;
            final finish = i + 1 < tags.length
                ? stamp(tags[i + 1], delta)
                : null;
            if (finish != null && finish < begin)
              throw const FormatException(
                'Enhanced lyric word timestamps must be in order.',
              );
            final part = line.substring(
              tags[i].end,
              i + 1 < tags.length ? tags[i + 1].start : line.length,
            );
            final from = text.length;
            text.write(part);
            if (part.isNotEmpty)
              spans.add(
                TimedTextSpan(from, text.length, begin, finish ?? maxTime),
              );
            if (i == tags.length - 1 && part.trim().isEmpty) end = begin;
          }
        }
        final value = text.toString().trimRight();
        if (value.length > 4000 ||
            rows.length >= 4000 ||
            (totalSpans += spans.length) > 20000)
          throw const FormatException(
            'Timed text exceeds cue, word or line-length limits.',
          );
        if (end != null && end < start)
          throw const FormatException(
            'The lyric end marker precedes its line.',
          );
        rows.add(
          TimedTextCue(
            start,
            end,
            value,
            spans: [
              for (final span in spans)
                if (span.from < value.length)
                  TimedTextSpan(
                    span.from,
                    math.min(span.to, value.length),
                    span.start,
                    span.end,
                  ),
            ],
          ),
        );
      }
    }
    rows.sort((a, b) => a.start.compareTo(b.start));
    return [
      for (var i = 0; i < rows.length; i++)
        () {
          final cue = rows[i];
          int? next;
          for (var n = i + 1; n < rows.length; n++) {
            if (rows[n].start > cue.start) {
              next = rows[n].start;
              break;
            }
          }
          final end = cue.end ?? next;
          return TimedTextCue(
            cue.start,
            end,
            cue.text,
            spans: [
              for (final s in cue.spans)
                TimedTextSpan(
                  s.from,
                  s.to,
                  s.start,
                  math.min(s.end, end ?? maxTime),
                ),
            ],
          );
        }(),
    ];
  }

  static List<TimedTextCue> _ttml(String text) {
    if (RegExp(r'<!\s*(DOCTYPE|ENTITY)', caseSensitive: false).hasMatch(text))
      throw const FormatException(
        'TTML declarations with DTDs/entities are not supported.',
      );
    try {
      var depth = 0, count = 0;
      for (final event in events.parseEvents(text)) {
        if (++count > 50000)
          throw const FormatException('TTML exceeds 50,000 XML events.');
        if (event is events.XmlStartElementEvent &&
            !event.isSelfClosing &&
            ++depth > 64)
          throw const FormatException('TTML exceeds 64 nested elements.');
        if (event is events.XmlEndElementEvent) depth--;
      }
      final root = XmlDocument.parse(text).rootElement;
      if (root.name.local != 'tt' ||
          (root.namespaceUri != null &&
              root.namespaceUri!.isNotEmpty &&
              !{
                'http://www.w3.org/ns/ttml',
                'http://www.w3.org/2006/10/ttaf1',
              }.contains(root.namespaceUri)))
        throw const FormatException(
          'Choose a TTML document with a tt root element.',
        );
      final appleLyrics = root.attributes.any(
        (a) => a.value == 'http://itunes.apple.com/lyric-ttml-extensions',
      );
      String? attr(XmlElement e, String name) {
        for (final a in e.attributes) {
          if (a.name.local == name) return a.value;
        }
        return null;
      }

      if ((attr(root, 'timeBase') ?? 'media') != 'media' ||
          !{
            'nonDrop',
            'nonDropFrame',
          }.contains(attr(root, 'dropMode') ?? 'nonDrop'))
        throw const FormatException(
          'Only media-time, non-drop-frame TTML timing is supported.',
        );
      double positive(String? value, double fallback) {
        final n = value == null ? fallback : double.tryParse(value);
        if (n == null || !n.isFinite || n <= 0 || n > 1000000)
          throw const FormatException('Invalid TTML timing rate.');
        return n;
      }

      final nominal = positive(attr(root, 'frameRate'), 30),
          subFrame = positive(attr(root, 'subFrameRate'), 1);
      final multiplier = (attr(root, 'frameRateMultiplier') ?? '1 1')
          .trim()
          .split(RegExp(r'\s+'));
      if (multiplier.length != 2)
        throw const FormatException('Invalid TTML frame-rate multiplier.');
      final fps =
          nominal * positive(multiplier[0], 1) / positive(multiplier[1], 1);
      final ticks = positive(
        attr(root, 'tickRate'),
        attr(root, 'frameRate') == null ? 1 : fps * subFrame,
      );
      int time(String value) {
        if (appleLyrics && RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value.trim()))
          return _bounded(double.parse(value.trim()) * 1000);
        final offset = RegExp(
          r'^(\d+(?:\.\d+)?)(ms|h|m|s|f|t)$',
        ).firstMatch(value.trim());
        if (offset != null)
          return _bounded(
            double.parse(offset[1]!) *
                switch (offset[2]) {
                  'h' => 3600000,
                  'm' => 60000,
                  's' => 1000,
                  'f' => 1000 / fps,
                  't' => 1000 / ticks,
                  _ => 1,
                },
          );
        final clock = RegExp(
          r'^(?:(\d+):)?(\d{2}):(\d{2})(?:\.(\d+)|:(\d+)(?:\.(\d+))?)?$',
        ).firstMatch(value.trim());
        if (clock == null ||
            int.parse(clock[2]!) > 59 ||
            int.parse(clock[3]!) > 59)
          throw FormatException('Unsupported TTML timestamp: $value');
        final frames = int.parse(clock[5] ?? '0'),
            sub = int.parse(clock[6] ?? '0');
        if (frames >= nominal || sub >= subFrame)
          throw const FormatException('Invalid TTML frame or subframe value.');
        return _bounded(
          ((int.parse(clock[1] ?? '0') * 60 + int.parse(clock[2]!)) * 60 +
                      int.parse(clock[3]!)) *
                  1000 +
              (clock[4] == null ? 0 : double.parse('0.${clock[4]}') * 1000) +
              (frames + sub / subFrame) * 1000 / fps,
        );
      }

      final timing = <XmlElement, (int, int)>{};
      final paragraphs = <XmlElement>[];
      const content = {'body', 'div', 'p', 'span', 'br'};
      (int, int) resolve(XmlElement e, int reference, int parentEnd) {
        final begin = attr(e, 'begin') == null
            ? reference
            : (appleLyrics ? 0 : reference) + time(attr(e, 'begin')!);
        var end = parentEnd;
        if (attr(e, 'end') != null)
          end = math.min(
            end,
            (appleLyrics ? 0 : reference) + time(attr(e, 'end')!),
          );
        if (attr(e, 'dur') != null)
          end = math.min(end, begin + time(attr(e, 'dur')!));
        end = math.max(begin, end);
        final seq = (attr(e, 'timeContainer') ?? 'par') == 'seq';
        var cursor = begin, inferred = begin;
        var children = 0;
        for (final child in e.childElements.where(
          (c) => content.contains(c.name.local),
        )) {
          if (seq && cursor >= end) break;
          final range = resolve(child, seq ? cursor : begin, end);
          cursor = range.$2;
          inferred = math.max(inferred, cursor);
          children++;
        }
        if (children > 0 && attr(e, 'end') == null && attr(e, 'dur') == null)
          end = math.min(end, inferred);
        timing[e] = (math.min(begin, maxTime), math.min(end, maxTime));
        if (e.name.local == 'p') paragraphs.add(e);
        return timing[e]!;
      }

      for (final body in root.childElements.where(
        (e) => e.name.local == 'body',
      ))
        resolve(body, 0, maxTime);
      final result = <TimedTextCue>[];
      var totalSpans = 0;
      for (final p in paragraphs) {
        final bounds = timing[p]!;
        if (bounds.$2 <= bounds.$1) continue;
        final out = StringBuffer(), spans = <TimedTextSpan>[];
        var lastCharacter = '';
        void append(XmlElement e, (int, int) range, bool preserve) {
          final space = attr(e, 'space');
          preserve = space == 'preserve' || space != 'default' && preserve;
          for (final node in e.children) {
            if (node is XmlText || node is XmlCDATA) {
              var value = node.value ?? '';
              if (!preserve) {
                value = value.replaceAll(RegExp(r'\s+'), ' ');
                if (out.isEmpty ||
                    lastCharacter == ' ' ||
                    lastCharacter == '\n')
                  value = value.trimLeft();
              }
              final from = out.length;
              out.write(value);
              if (value.isNotEmpty)
                lastCharacter = value.substring(value.length - 1);
              if (value.isNotEmpty)
                spans.add(
                  TimedTextSpan(
                    from,
                    out.length,
                    math.max(bounds.$1, range.$1),
                    math.min(bounds.$2, range.$2),
                  ),
                );
            } else if (node is XmlElement && node.name.local == 'br') {
              out.write('\n');
              lastCharacter = '\n';
            } else if (node is XmlElement &&
                node.name.local == 'span' &&
                timing.containsKey(node))
              append(node, timing[node]!, preserve);
          }
        }

        var preserve = attr(root, 'space') == 'preserve';
        for (final ancestor
            in p.ancestors.whereType<XmlElement>().toList().reversed) {
          if (attr(ancestor, 'space') != null)
            preserve = attr(ancestor, 'space') == 'preserve';
        }
        append(p, bounds, preserve);
        final value = out.toString().trimRight();
        if (value.isEmpty) continue;
        if (value.length > 4000 ||
            result.length >= 4000 ||
            (totalSpans += spans.length) > 20000)
          throw const FormatException(
            'TTML exceeds cue, span or line-length limits.',
          );
        result.add(
          TimedTextCue(
            bounds.$1,
            bounds.$2 == maxTime ? null : bounds.$2,
            value,
            spans: [
              for (final s in spans)
                if (s.from < value.length && s.end > s.start)
                  TimedTextSpan(
                    s.from,
                    math.min(s.to, value.length),
                    s.start,
                    s.end,
                  ),
            ],
          ),
        );
      }
      if (result.isEmpty)
        throw const FormatException(
          'No timed text paragraphs were found in TTML.',
        );
      result.sort((a, b) => a.start.compareTo(b.start));
      return result;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('The TTML document could not be parsed.');
    }
  }
}
