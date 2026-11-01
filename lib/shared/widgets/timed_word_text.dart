import 'package:flutter/material.dart';
import '../../domain/media/timed_text.dart';

/// Plain text with measured word/syllable intervals. No markup is executed.
class TimedWordText extends StatelessWidget {
  const TimedWordText({
    super.key,
    required this.text,
    required this.spans,
    required this.position,
    required this.style,
    this.highlight = const Color(0xffffd180),
  });
  final String text;
  final List<TimedTextSpan> spans;
  final int position;
  final TextStyle style;
  final Color highlight;
  @override
  Widget build(BuildContext context) {
    if (spans.isEmpty)
      return Text(text, textAlign: TextAlign.center, style: style);
    final children = <TextSpan>[];
    var at = 0;
    for (final span in spans) {
      if (span.from < at || span.to > text.length || span.to <= span.from)
        continue;
      if (span.from > at)
        children.add(TextSpan(text: text.substring(at, span.from)));
      children.add(
        TextSpan(
          text: text.substring(span.from, span.to),
          style: span.active(position)
              ? TextStyle(color: highlight, fontWeight: FontWeight.w700)
              : null,
        ),
      );
      at = span.to;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(style: style, children: children),
      textAlign: TextAlign.center,
      semanticsLabel: text,
    );
  }
}
