import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/playback/remote_playback_controller.dart';

void main() {
  test('only the current player receives validated ordered commands', () async {
    final controller = RemotePlaybackController(), events = <String>[];
    final old = controller.attach(
      status: () => {'active': true},
      perform: (action, value) async {
        events.add('old:$action');
      },
    );
    controller.attach(
      status: () => {'active': true, 'title': 'Fixture'},
      perform: (action, value) async {
        events.add(action);
      },
    );
    controller.detach(old);
    await Future.wait([
      controller.execute('play', null),
      controller.execute('seek', 3),
      controller.execute('pause', null),
    ]);
    expect(events, ['play', 'seek', 'pause']);
    expect(() => controller.execute('rate', double.nan), throwsFormatException);
    expect(() => controller.execute('open', null), throwsFormatException);
    expect(() => controller.execute('seek', -1), throwsFormatException);
    expect(controller.status['title'], 'Fixture');
  });
}
