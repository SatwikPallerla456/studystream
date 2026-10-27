import 'dart:io';
import 'dart:ffi';
import 'package:drift/native.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/music/music_session.dart';
import 'package:study_stream/data/sync/lan_sync_client.dart';
import 'package:study_stream/domain/services/player_library_repository.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:study_stream/data/music/audio_reactivity.dart';

Uint8List tone(
  double amplitude, {
  int samples = 16000,
  double frequency = 220,
}) {
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(
      i * 2,
      (32767 * amplitude * math.sin(2 * math.pi * frequency * i / 16000))
          .round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

Uint8List wav(Uint8List pcm) {
  final header = ByteData(44);
  void text(int at, String value) {
    for (var i = 0; i < value.length; i++) {
      header.setUint8(at + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  header.setUint32(4, pcm.length + 36, Endian.little);
  text(8, 'WAVEfmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 16000, Endian.little);
  header.setUint32(28, 32000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  text(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}

Future<AudioLevel> measured(
  PcmAudioAnalyzer analyzer,
  Media media,
  Duration at,
) async {
  final limit = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(limit)) {
    final value = analyzer.sample(media, at);
    if (value != null) return value;
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
  fail('No decoded level at $at: ${analyzer.message}');
}

Future<void> verifyListeningSession(File file) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final client = LanSyncClient(database);
  final session = MusicSession(
    database,
    client,
    PlayerLibraryRepository(database),
  );
  final previousTestMode = NativePlayer.test;
  NativePlayer.test = true; // Run the actual session with a silent main output.
  Future<void> waitFor(bool Function() condition) async {
    final until = DateTime.now().add(const Duration(seconds: 8));
    while (!condition() && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    expect(
      condition(),
      isTrue,
      reason: '${session.error}; ${session.meterMessage}',
    );
  }

  try {
    await database.customStatement(
      "INSERT INTO libraries (id,title,root_folder_path,created_at,updated_at) VALUES ('music','Music','/test',0,0)",
    );
    await database.customStatement(
      "INSERT INTO sections (id,library_id,title,order_index,folder_path) VALUES ('album','music','Album',0,'/test')",
    );
    await database.customStatement(
      "INSERT INTO items (id,library_id,section_id,title,filename,file_path,relative_path,item_type,order_index) VALUES ('effect','music','album','Effect','test.wav',?,'test.wav','audio',0)",
      [file.path],
    );
    await session.initialize('effect');
    await waitFor(() => session.energy > .01 && session.meterMessage == null);
    final quietEnergy = session.energy;
    await session.seek(const Duration(seconds: 5));
    await waitFor(() => session.energy > quietEnergy * 3);
    expect(session.envelope, isNotEmpty);
    expect(session.error, isNull);
    expect(
      await (session.player!.platform as NativePlayer).getProperty('af'),
      isEmpty,
    );
    await session.pause();
    final energyBeforePause = session.energy;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(session.energy, lessThan(energyBeforePause));
    await session.play();
    await waitFor(() => session.player!.state.playing && session.energy > .1);
  } finally {
    await session.close();
    session.dispose();
    await client.dispose();
    await database.close();
    NativePlayer.test = previousTestMode;
  }
}

void main() {
  test('PCM measurements distinguish silence, quiet music and loud music', () {
    final silence = AudioLevel.decodePcm(Uint8List(1280)).single;
    final quiet = AudioLevel.decodePcm(tone(.05)).first;
    final loud = AudioLevel.decodePcm(tone(.9)).first;
    expect(silence.rmsDb, closeTo(-120, 1e-9));
    expect(quiet.rmsDb, closeTo(-29, .5));
    expect(loud.rmsDb, closeTo(-3.9, .5));
    expect(loud.rmsDb - quiet.rmsDb, greaterThan(24));
    expect(loud.peakDb, greaterThan(quiet.peakDb));
    expect(loud.zeroCrossingRate, inInclusiveRange(.02, .04));
  });
  test('partial PCM frames and silence produce finite bounded values', () {
    expect(AudioLevel.decodePcm(Uint8List(1)), isEmpty);
    for (final level in AudioLevel.decodePcm(tone(.8, samples: 750))) {
      expect(level.rmsDb.isFinite, isTrue);
      expect(level.peakDb.isFinite, isTrue);
      expect(level.zeroCrossingRate, inInclusiveRange(0, 1));
    }
  });

  final nativePath = Platform.environment['TANGERINE_MPV_PATH'];
  test(
    'bundled native decoder measures actual music, seeks, authenticated streams and cleanup',
    () async {
      // flutter_tester does not inherit DYLD_FRAMEWORK_PATH. Preload the
      // app's existing signed framework dependencies by absolute path.
      if (Platform.isMacOS) {
        final frameworks = File(nativePath!).parent.parent.parent.parent;
        var pending = frameworks
            .listSync()
            .whereType<Directory>()
            .where((d) => d.path.endsWith('.framework'))
            .toList();
        for (var pass = 0; pass < 20 && pending.isNotEmpty; pass++) {
          pending = pending.where((d) {
            final name = d.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last
                .replaceAll('.framework', '');
            try {
              DynamicLibrary.open('${d.path}/Versions/A/$name');
              return false;
            } catch (_) {
              return true;
            }
          }).toList();
        }
      }
      MediaKit.ensureInitialized(libmpv: nativePath);
      final dir = await Directory.systemTemp.createTemp(
        'tangerine-meter-test-',
      );
      final analyzer = PcmAudioAnalyzer();
      final playback = Player();
      HttpServer? server;
      try {
        final recording = wav(
          Uint8List.fromList([
            ...tone(.03, samples: 16000 * 3),
            ...tone(.9, samples: 16000 * 12),
            ...tone(.1, samples: 16000 * 3),
          ]),
        );
        final file = await File('${dir.path}/test.wav').writeAsBytes(recording);
        final media = Media(file.path);
        final nativePlayback = playback.platform as NativePlayer;
        await nativePlayback.setProperty('ao', 'null');
        await playback.open(media);
        final quiet = await measured(
          analyzer,
          media,
          const Duration(seconds: 1),
        );
        final loud = await measured(
          analyzer,
          media,
          const Duration(seconds: 5),
        );
        expect(loud.rmsDb - quiet.rmsDb, greaterThan(25));
        // Cross the 12-second window and seek back without reusing wrong samples.
        final ending = await measured(
          analyzer,
          media,
          const Duration(seconds: 16),
        );
        expect(loud.rmsDb - ending.rmsDb, greaterThan(15));
        final rewind = await measured(
          analyzer,
          media,
          const Duration(seconds: 1),
        );
        expect(rewind.rmsDb, closeTo(quiet.rmsDb, .5));
        if (Platform.isMacOS) {
          final encoded = '${dir.path}/test.m4a';
          final result = await Process.run('/usr/bin/afconvert', [
            '-f',
            'm4af',
            '-d',
            'aac',
            file.path,
            encoded,
          ]);
          expect(result.exitCode, 0, reason: '${result.stderr}');
          final aac = Media(encoded);
          final aacQuiet = await measured(
            analyzer,
            aac,
            const Duration(seconds: 1),
          );
          final aacLoud = await measured(
            analyzer,
            aac,
            const Duration(seconds: 5),
          );
          expect(aacLoud.rmsDb - aacQuiet.rmsDb, greaterThan(25));
        }
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var authorized = 0;
        server.listen((request) async {
          if (request.headers.value('Authorization') != 'Bearer test-only') {
            request.response.statusCode = 401;
          } else {
            authorized++;
            request.response.headers.contentType = ContentType('audio', 'wav');
            request.response.headers.set('Accept-Ranges', 'bytes');
            final range = request.headers.value('Range');
            final begin = range == null
                ? 0
                : int.parse(
                    RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!,
                  );
            if (range != null) {
              request.response.statusCode = HttpStatus.partialContent;
              request.response.headers.set(
                'Content-Range',
                'bytes $begin-${recording.length - 1}/${recording.length}',
              );
            }
            request.response.contentLength = recording.length - begin;
            if (request.method != 'HEAD') {
              request.response.add(recording.sublist(begin));
            }
          }
          await request.response.close();
        });
        final remote = await measured(
          analyzer,
          Media(
            'http://127.0.0.1:${server.port}/audio',
            httpHeaders: {'Authorization': 'Bearer test-only'},
          ),
          const Duration(seconds: 1),
        );
        expect(remote.rmsDb, closeTo(quiet.rmsDb, .5));
        expect(authorized, greaterThan(0));
        expect(analyzer.message, isNull);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(playback.state.playing, isTrue);
        expect(playback.state.position, greaterThan(Duration.zero));
        expect(await nativePlayback.getProperty('af'), isEmpty);
        await analyzer.close();
        expect(analyzer.sample(media, Duration.zero), isNull);
        await playback.pause();
        await verifyListeningSession(file);
      } finally {
        await analyzer.close();
        await playback.dispose();
        await server?.close(force: true);
        await dir.delete(recursive: true);
      }
    },
    skip: nativePath == null
        ? 'Set TANGERINE_MPV_PATH for bundled decoder integration'
        : false,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
