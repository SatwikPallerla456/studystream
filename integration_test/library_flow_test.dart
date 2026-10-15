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
import 'package:pdfrx/pdfrx.dart';
import 'package:study_stream/app.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/indexer/library_indexer.dart';
import 'package:study_stream/data/providers/app_providers.dart';
import 'package:study_stream/data/sync/lan_sync_client.dart';
import 'package:study_stream/domain/services/progress_writer.dart';
import 'package:study_stream/domain/services/resume_service.dart';
import 'package:study_stream/features/reader/pdf_reader_screen.dart';
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
      Player? player;
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
      player = Player();
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
      player = Player();
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
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      await tester.tap(find.text('Go to page').last);
      await tester.pumpAndSettle();
      expect(viewer.controller!.pageNumber, 1);
      await tester.tap(find.text('1 / 3'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2');
      await tester.pump();
      await tester.tap(find.text('Go to page').last);
      await tester.pumpAndSettle();
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
      expect(find.text('Native fixture course'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
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
