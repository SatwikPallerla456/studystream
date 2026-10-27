import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/music/music_session.dart';
import 'package:study_stream/features/music/music_art.dart';

class _VisualSession extends ChangeNotifier implements MusicSession {
  @override
  MusicTrack? get track => null;
  @override
  double energy = .05, beat = 0, grit = 0;
  @override
  double visualIntensity = 1;
  @override
  String visualStyle = 'auto';
  @override
  List<double> envelope = [.05, .05];
  void loud() {
    energy = .95;
    beat = 1;
    grit = .9;
    envelope = [.05, .2, .95, .3];
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'artwork atmosphere reacts to music and respects reduced motion and Off',
    (tester) async {
      final session = _VisualSession();
      final key = GlobalKey();
      Widget scene({bool reduced = false}) => ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: RepaintBoundary(
              key: key,
              child: MusicAtmosphere(
                session: session,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      Future<Uint8List> pixels() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: .25);
          try {
            return (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        }))!;
      }

      await tester.pumpWidget(scene());
      await tester.pump();
      final quiet = await pixels();
      session.loud();
      await tester.pump();
      final loud = await pixels();
      expect(
        loud,
        isNot(orderedEquals(quiet)),
        reason: 'Measured energy must change the rendered atmosphere',
      );
      await tester.pumpWidget(scene(reduced: true));
      await tester.pump();
      final reducedLoud = await pixels();
      session.energy = 0;
      session.beat = 0;
      session.notifyListeners();
      await tester.pump();
      expect(await pixels(), orderedEquals(reducedLoud));
      session.visualStyle = 'off';
      await tester.pumpWidget(scene());
      await tester.pump();
      final off = await pixels();
      session.loud();
      await tester.pump();
      expect(await pixels(), orderedEquals(off));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
