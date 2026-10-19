import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:study_stream/data/playback/playback_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tangerine/test-playback');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'native boundary normalizes file URLs, restores paused transport and releases once',
    () async {
      var playing = false;
      var position = 0;
      var releases = 0;
      String? opened;
      messenger.setMockMethodCallHandler(channel, (call) async {
        final arguments = (call.arguments as Map?) ?? {};
        switch (call.method) {
          case 'create':
            return 1;
          case 'open':
            opened = arguments['uri'] as String;
            playing = true;
          case 'pause':
            playing = false;
          case 'play':
            playing = true;
          case 'seek':
            position = arguments['value'] as int;
          case 'dispose':
            releases++;
          case 'state':
            return {
              'position': position,
              'duration': 8000,
              'playing': playing,
              'completed': false,
              'buffering': false,
              'volume': 75,
              'rate': 1,
              'audio': [
                {'id': 0, 'title': 'English'},
              ],
              'subtitles': [
                {'id': -1, 'title': 'Off'},
              ],
              'audioTrack': 0,
              'subtitleTrack': -1,
              'error': false,
            };
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final engine = await NativeVlcEngine.create(channel: channel);
      addTearDown(engine.dispose);
      await engine.open(Media('/tmp/Media with spaces.mp4'), play: false);
      expect(Uri.parse(opened!).toFilePath(), '/tmp/Media with spaces.mp4');
      expect(engine.state.duration, const Duration(seconds: 8));
      expect(engine.state.playing, false);
      expect(engine.state.tracks.audio.single.title, 'English');
      await engine.seek(const Duration(seconds: -1));
      expect(engine.state.position, Duration.zero);
      await engine.seek(const Duration(seconds: 100));
      expect(engine.state.position, const Duration(seconds: 8));
      await engine.playOrPause();
      expect(engine.state.playing, true);
      await engine.dispose();
      await engine.dispose();
      expect(releases, 1);
    },
  );

  test('native errors surface without selecting the interim player', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'create') {
        throw PlatformException(
          code: 'LIBVLC',
          message: 'Synthetic startup failure',
        );
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await expectLater(
      NativeVlcEngine.create(channel: channel),
      throwsA(isA<PlatformException>()),
    );
  });
}
