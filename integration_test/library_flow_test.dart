import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:study_stream/data/playback/playback_engine.dart';
import 'package:study_stream/data/sync/lan_sync_server.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:study_stream/app.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/indexer/library_indexer.dart';
import 'package:study_stream/data/providers/app_providers.dart';
import 'package:study_stream/data/sync/lan_sync_client.dart';
import 'package:study_stream/domain/services/progress_writer.dart';
import 'package:study_stream/domain/services/resume_service.dart';
import 'package:study_stream/features/reader/pdf_reader_screen.dart';
import 'package:study_stream/features/player/media_player_screen.dart';
import 'package:study_stream/core/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'valid audio playback and PDF rendering survive a disk database restart',
    (tester) async {
      const secure = SecureCredentialStore(
        key: 'studystream.integration-test-only',
      );
      await secure.write('synthetic-test-credential');
      expect(await secure.read(), 'synthetic-test-credential');
      await secure.clear();
      MediaKit.ensureInitialized();
      await pdfrxFlutterInitialize();
      final root = await Directory.systemTemp.createTemp(
        'study-stream-native-',
      );
      final module = await Directory(
        '${root.path}/course/01 Module',
      ).create(recursive: true);
      final audio = await File(
        '${module.path}/01 Lesson.wav',
      ).writeAsBytes(_wave());
      final pdf = await File(
        '${module.path}/02 Handbook.pdf',
      ).writeAsBytes(_pdf());
      final databaseFile = File('${root.path}/learning.sqlite');
      var database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      PlaybackEngine? player;
      addTearDown(() async {
        await player?.dispose();
        await database.close();
        await root.delete(recursive: true);
      });

      final result = await LibraryIndexer(database).scanRootFolder(
        rootFolderPath: '${root.path}/course',
        title: 'Native fixture course',
      );
      final items = await database.getItemsForLibrary(result.libraryId);
      final media = items.singleWhere((i) => i.itemType == 'audio');
      final document = items.singleWhere((i) => i.itemType == 'pdf');
      player = await PlaybackEngine.create();
      await player.setVolume(0);
      await player.open(Media(audio.path));
      for (
        var i = 0;
        i < 30 && player.state.position.inMilliseconds < 200;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(player.state.duration.inSeconds, 8);
      expect(player.state.position.inMilliseconds, greaterThan(0));
      await player.seek(const Duration(seconds: 4));
      await player.pause();
      final writer =
          MediaProgressWriter(
            database: database,
            item: media,
            resumeRewindSeconds: 1,
          )..seed(
            position: const Duration(seconds: 4),
            duration: player.state.duration,
            speed: 1.25,
          );
      await writer.dispose();
      await player.dispose();
      player = null;
      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      final saved = (await database.getPlaybackByItemId(media.id))!;
      expect(saved.lastPositionSeconds, 4);
      expect(
        ResumeService.mediaResumeSeconds(
          saved.lastPositionSeconds,
          durationSeconds: saved.durationSeconds,
          rewindSeconds: 1,
        ),
        4,
      );
      player = await PlaybackEngine.create();
      await player.setVolume(0);
      await player.open(Media(audio.path), play: false);
      if (player.state.duration == Duration.zero) {
        await player.stream.duration
            .firstWhere((value) => value > Duration.zero)
            .timeout(const Duration(seconds: 10));
      }
      await player.seek(
        Duration(milliseconds: (saved.lastPositionSeconds * 1000).round()),
      );
      await player.play();
      await player.stream.position
          .firstWhere((value) => value.inSeconds >= 4)
          .timeout(const Duration(seconds: 10));
      expect(player.state.position.inSeconds, greaterThanOrEqualTo(4));
      await player.dispose();
      player = null;

      final openedPdf = await PdfDocument.openFile(pdf.path);
      expect(openedPdf.pages, hasLength(3));
      final bitmap = await openedPdf.pages.first.render(
        width: 306,
        height: 396,
      );
      expect(bitmap, isNotNull);
      expect(bitmap!.width, 306);
      bitmap.dispose();
      final text = await openedPdf.pages.first.loadText();
      expect(text?.fullText, contains('StudyStream fixture'));
      await openedPdf.dispose();

      final reading = ReadingProgressWriter(database: database, item: document)
        ..currentPage = 2
        ..totalPages = 3
        ..zoom = 1.4
        ..readingMode = 'fitWidth'
        ..pagesVisited = 2;
      await reading.dispose();
      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      expect((await database.getReadingByItemId(document.id))!.resumePage, 2);
      expect((await database.getReadingByItemId(document.id))!.zoom, 1.4);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: PdfReaderScreen(itemId: document.id),
          ),
        ),
      );
      for (
        var i = 0;
        i < 40 && find.text('Preparing your document').evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PdfViewer), findsOneWidget);
      final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
      expect(viewer.controller!.pageNumber, 2);
      expect(viewer.controller!.currentZoom, closeTo(1.4, .05));
      await tester.tap(find.text('2 / 3'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      await tester.tap(find.text('Go to page').last);
      await tester.pump(const Duration(milliseconds: 400));
      for (
        var attempt = 0;
        attempt < 30 &&
            (viewer.controller!.pageNumber != 1 ||
                find.text('1 / 3').evaluate().isEmpty);
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(viewer.controller!.pageNumber, 1);
      await tester.tap(find.text('1 / 3'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), '2');
      await tester.pump();
      await tester.tap(find.text('Go to page').last);
      await tester.pump(const Duration(milliseconds: 400));
      for (
        var attempt = 0;
        attempt < 30 &&
            (viewer.controller!.pageNumber != 2 ||
                find.text('2 / 3').evaluate().isEmpty);
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(viewer.controller!.pageNumber, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const StudyMediaPlayerApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text('Use as player'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Use as player'));
      await tester.pump(const Duration(milliseconds: 400));
      // The route can settle before the disk database's catalogue stream emits.
      for (
        var attempt = 0;
        attempt < 60 && find.text('Native fixture course').evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Native fixture course'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'libVLC renders local and protected video with tracks, subtitles and lifecycle cleanup',
    (tester) async {
      if (!Platform.isMacOS) return;
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final root = await Directory.systemTemp.createTemp('tangerine-video-');
      const encodedVideo = String.fromEnvironment(
        'TANGERINE_VIDEO_FIXTURE_BASE64',
      );
      final video = await File(
        '${root.path}/motion.mp4',
      ).writeAsBytes(base64Decode(encodedVideo));
      final subtitles = await File('${root.path}/motion.srt').writeAsString(
        '1\n00:00:00,000 --> 00:00:10,000\nTangerine subtitle fixture\n',
      );
      final indexed = await LibraryIndexer(
        database,
      ).scanRootFolder(rootFolderPath: root.path, title: 'Video fixture');
      final item = (await database.getItemsForLibrary(
        indexed.libraryId,
      )).single;
      final server = LanSyncServer(database);
      final client = HttpClient();
      NativeVlcEngine? engine;
      addTearDown(() async {
        await engine?.dispose();
        client.close(force: true);
        await server.dispose();
        await database.close();
        await root.delete(recursive: true);
      });
      debugPrint('VLC fixture: create player');
      engine = await NativeVlcEngine.create();
      debugPrint('VLC fixture: open local video');
      await engine.open(Media(video.path), play: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 640,
              height: 360,
              child: engine.videoSurface(),
            ),
          ),
        ),
      );
      debugPrint('VLC fixture: play');
      await engine.play();
      for (
        var attempt = 0;
        attempt < 60 && engine.diagnostics['hasVideoOutput'] != true;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
        await engine.refresh();
      }
      expect(engine.backendName, contains('libVLC'));
      expect(engine.diagnostics['hasVideoOutput'], true);
      expect(engine.state.width, 640);
      expect(engine.state.height, 360);
      debugPrint('VLC fixture: local rendered; load subtitles');
      await engine.setSubtitleTrack(SubtitleTrack.uri(subtitles.path));
      await engine.setRate(1.25);
      await engine.seek(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 700));
      await engine.pause();
      expect(engine.state.position.inMilliseconds, greaterThanOrEqualTo(3500));
      expect(engine.state.playing, false);
      expect(engine.state.rate, closeTo(1.25, .01));
      await engine.setEqualizer(
        enabled: true,
        preamp: 0,
        bands: List.filled(10, 0),
      );
      await engine.setPicture({'brightness': 1.1});
      debugPrint('VLC fixture: effects applied; next frame');
      await engine.nextFrame();
      await tester.pump(const Duration(milliseconds: 400));
      await engine.refresh();
      final statistics = engine.diagnostics['statistics'] as Map;
      expect(
        int.parse(statistics['Decoded video frames'] as String),
        greaterThan(0),
      );
      expect(
        int.parse(statistics['Displayed pictures'] as String),
        greaterThan(0),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      await engine.dispose();
      engine = null;

      debugPrint('VLC fixture: pair protected stream');
      await server.start(name: 'Tangerine fixture server');
      final base = Uri.parse('http://127.0.0.1:${server.state.port}');
      final pairing = await client.postUrl(base.resolve('/v1/pair'));
      pairing.headers.contentType = ContentType.json;
      pairing.write(
        jsonEncode({
          'name': 'Native libVLC fixture',
          'code': server.state.pairingCode,
        }),
      );
      final paired = await pairing.close();
      final credentials =
          jsonDecode(await utf8.decoder.bind(paired).join()) as Map;
      expect(paired.statusCode, HttpStatus.created);
      debugPrint('VLC fixture: create player');
      engine = await NativeVlcEngine.create();
      await engine.open(
        Media(
          base.resolve('/v1/media/${item.id}').toString(),
          httpHeaders: {'Authorization': 'Bearer ${credentials['token']}'},
        ),
        play: false,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: engine.videoSurface())),
      );
      debugPrint('VLC fixture: play');
      await engine.play();
      for (
        var attempt = 0;
        attempt < 60 && engine.state.position.inMilliseconds < 200;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
        await engine.refresh();
      }
      expect(engine.state.position.inMilliseconds, greaterThan(0));
      await engine.seek(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 700));
      await engine.pause();
      expect(engine.state.position.inMilliseconds, greaterThanOrEqualTo(5000));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      await engine.dispose();
      engine = null;

      debugPrint('VLC fixture: merged player screen and durable progress');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: MediaPlayerScreen(itemId: item.id),
          ),
        ),
      );
      for (
        var attempt = 0;
        attempt < 100 && find.byTooltip('Play').evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(AppKitView), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Playback tools'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Equalizer'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      final savedVideo = await database.getPlaybackByItemId(item.id);
      expect(savedVideo, isNotNull);
      expect(savedVideo!.lastPositionSeconds, greaterThan(0));
    },
    skip: const String.fromEnvironment(
      'TANGERINE_VIDEO_FIXTURE_BASE64',
    ).isEmpty,
  );
  testWidgets(
    'native outputs finalize decodable files and mini-player shares the same playback',
    (tester) async {
      if (!Platform.isMacOS) return;
      const encoded = String.fromEnvironment('TANGERINE_VIDEO_FIXTURE_BASE64');
      final root = await Directory.systemTemp.createTemp('tangerine-output-');
      final video = await File(
        '${root.path}/video.mp4',
      ).writeAsBytes(base64Decode(encoded));
      final audio = await File('${root.path}/audio.wav').writeAsBytes(_wave());
      NativeVlcEngine? engine;
      addTearDown(() async {
        await engine?.dispose();
        await root.delete(recursive: true);
      });
      for (final format in ['mp4', 'webm', 'mp3', 'flac', 'ts']) {
        debugPrint('Native output fixture: $format');
        engine = await NativeVlcEngine.create();
        await engine.open(
          Media(['mp3', 'flac'].contains(format) ? audio.path : video.path),
          play: false,
        );
        final destination = '${root.path}/converted.$format';
        final id = await engine.startOutput(
          mode: 'convert',
          format: format,
          destination: destination,
        );
        expect(id, isNotNull);
        Map? job;
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await engine.refresh();
          job = (engine.diagnostics['jobs'] as List)
              .cast<Map>()
              .where((value) => value['id'] == id)
              .firstOrNull;
          if (job?['finished'] == true) break;
        }
        expect(job?['finished'], true);
        expect(job?['error'], '');
        expect(await File(destination).length(), greaterThan(0));
        await engine.dispose();
        engine = await NativeVlcEngine.create();
        await engine.open(Media(destination), play: false);
        expect(engine.state.duration, greaterThan(Duration.zero));
        await engine.dispose();
        engine = null;
      }
      engine = await NativeVlcEngine.create();
      await engine.open(Media(video.path), play: false);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: engine.videoSurface())),
      );
      await engine.play();
      await tester.pump(const Duration(milliseconds: 500));
      await engine.toggleMini();
      await tester.pump(const Duration(milliseconds: 300));
      await engine.refresh();
      expect(engine.diagnostics['miniature'], true);
      await engine.toggleMini();
      await tester.pump(const Duration(milliseconds: 300));
      await engine.refresh();
      expect(engine.diagnostics['miniature'], false);
      expect(engine.diagnostics['hasVideoOutput'], true);
      final destination = '${root.path}/recording.ts';
      final recording = await engine.startOutput(
        mode: 'record',
        format: 'ts',
        destination: destination,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await engine.pause();
      await tester.pump(const Duration(milliseconds: 300));
      await engine.finishOutput(recording!);
      expect(await File(destination).length(), greaterThan(0));
      final job = (engine.diagnostics['jobs'] as List).cast<Map>().singleWhere(
        (row) => row['id'] == recording,
      );
      expect(job['state'], 'Complete');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      await engine.dispose();
      engine = null;
    },
    skip: const String.fromEnvironment(
      'TANGERINE_VIDEO_FIXTURE_BASE64',
    ).isEmpty,
  );
}

Uint8List _wave() {
  const samples = 8000 * 8;
  final data = ByteData(44 + samples * 2);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  text(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    data.setInt16(
      44 + i * 2,
      (500 * sin(2 * pi * 220 * i / 8000)).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

List<int> _pdf() {
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 5 0 R 7 0 R] /Count 3 >>',
  ];
  for (var i = 0; i < 3; i++) {
    final text =
        'BT /F1 24 Tf 72 700 Td (StudyStream fixture - page ${i + 1}) Tj ET';
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 9 0 R >> >> /Contents ${4 + i * 2} 0 R >>',
    );
    objects.add('<< /Length ${text.length} >>\nstream\n$text\nendstream');
  }
  objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  var data = '%PDF-1.4\n';
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(data.length);
    data += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final xref = data.length;
  data += 'xref\n0 ${objects.length + 1}\n0000000000 65535 f \n';
  for (final offset in offsets) {
    data += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  data +=
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
  return ascii.encode(data);
}
