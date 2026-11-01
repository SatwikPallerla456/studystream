import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/domain/music/music_models.dart';
import 'package:study_stream/features/music/immersive_music_player.dart';

void main() {
  testWidgets(
    'lyrics follow playback and give manual scrolling back to the listener',
    (tester) async {
      final lines = LyricLine.parse(
        List.generate(
          80,
          (i) =>
              '[${(i ~/ 6).toString().padLeft(2, '0')}:${((i % 6) * 10).toString().padLeft(2, '0')}.00]Synthetic lyric line $i',
        ).join('\n'),
      );
      Duration? sought;
      Widget scene(Duration position) => MaterialApp(
        home: Scaffold(
          body: MusicLyricsViewport(
            lines: lines,
            position: position,
            playing: false,
            rate: 1,
            onSeek: (time) async {
              sought = time;
            },
          ),
        ),
      );
      await tester.pumpWidget(scene(const Duration(seconds: 200)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.pixels, greaterThan(0));
      final followed = scroll.position.pixels;
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(find.text('Current lyric'), findsOneWidget);
      final manual = scroll.position.pixels;
      await tester.pumpWidget(scene(const Duration(seconds: 250)));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, closeTo(manual, 1));
      await tester.tap(find.text('Current lyric'));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(followed));
      expect(find.text('Current lyric'), findsNothing);
      final targets = find
          .byType(GestureDetector)
          .evaluate()
          .where((e) => (e.widget as GestureDetector).onTap != null);
      final target = targets.first;
      (target.widget as GestureDetector).onTap!();
      await tester.pumpAndSettle();
      expect(sought, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
