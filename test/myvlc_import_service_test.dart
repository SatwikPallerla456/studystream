import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/domain/services/myvlc_import_service.dart';

void main() {
  late AppDatabase database;
  late Directory root;
  late File media;
  late File legacy;
  late Map<String, Object?> snapshot;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('tangerine-import-');
    media = await File('${root.path}/Video.mp4').writeAsBytes([1, 2, 3]);
    legacy = File('${root.path}/library.json');
    snapshot = {
      'items': [
        {
          'url': media.uri.toString(),
          'resumeTime': 42000,
          'lastPlayed': 800000000.0,
          'subtitleURL': Uri.file('${root.path}/Video.srt').toString(),
        },
      ],
      'queue': [media.uri.toString()],
      'playlists': [
        {
          'id': 'original-playlist-id',
          'title': 'Favourites',
          'mediaIDs': [media.uri.toString()],
        },
      ],
    };
    await legacy.writeAsString(jsonEncode(snapshot));
  });
  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test(
    'preview is read-only; import retains source, resume, queue and playlists and is idempotent',
    () async {
      final service = MyVlcImportService(database);
      final original = await legacy.readAsString();
      final preview = await service.preview(legacy);
      expect(preview.newItems, 1);
      expect(await database.select(database.items).get(), isEmpty);
      expect(await service.import(preview), 1);
      final item = (await database.select(database.items).get()).single;
      expect(
        (await database.getPlaybackByItemId(item.id))!.lastPositionSeconds,
        42,
      );
      expect(
        await database.getSetting('subtitle.${item.id}'),
        '${root.path}/Video.srt',
      );
      expect(jsonDecode((await database.getSetting('myvlc.queue'))!), [
        item.id,
      ]);
      expect(
        jsonDecode(
          (await database.getSetting('myvlc.playlists'))!,
        )['original-playlist-id']['itemIds'],
        [item.id],
      );
      await database.upsertPlayback(
        PlaybackProgressCompanion.insert(
          itemId: item.id,
          lastPositionSeconds: const Value(70),
          lastEventAt: Value(DateTime.now().millisecondsSinceEpoch),
          deviceId: 'test',
        ),
      );
      expect(
        await service.import(preview, conflict: MyVlcProgressConflict.useMyVlc),
        0,
      );
      expect(
        (await database.getPlaybackByItemId(item.id))!.lastPositionSeconds,
        70,
      );
      expect(await legacy.readAsString(), original);
      expect(await media.readAsBytes(), [1, 2, 3]);
    },
  );

  test('existing item keeps its identity and progress by default', () async {
    final service = MyVlcImportService(database);
    await service.import(await service.preview(legacy));
    final item = (await database.select(database.items).get()).single;
    await database.upsertPlayback(
      PlaybackProgressCompanion.insert(
        itemId: item.id,
        lastPositionSeconds: const Value(80),
        deviceId: 'test',
      ),
    );
    final preview = await service.preview(legacy);
    expect(preview.existingItems, 1);
    expect(preview.progressConflicts, 1);
    await service.import(preview);
    expect((await database.select(database.items).get()).single.id, item.id);
    expect(
      (await database.getPlaybackByItemId(item.id))!.lastPositionSeconds,
      80,
    );
  });

  test(
    'repeat import preserves a relinked file and its durable identity',
    () async {
      final service = MyVlcImportService(database);
      final preview = await service.preview(legacy);
      await service.import(preview);
      final item = (await database.select(database.items).get()).single;
      final moved = await media.rename('${root.path}/Renamed.mp4');
      await database.relinkItem(
        itemId: item.id,
        filePath: moved.path,
        filename: 'Renamed.mp4',
        relativePath: moved.path,
        modifiedAt: 1,
        fileSize: 3,
        fingerprint: 'synthetic-fixture',
      );
      final reopenedPreview = await service.preview(legacy);
      expect(reopenedPreview.newItems, 0);
      expect(reopenedPreview.existingItems, 1);
      expect(await service.import(reopenedPreview), 0);
      expect((await database.getItemById(item.id))!.filePath, moved.path);
      expect(
        (await database.getPlaybackByItemId(item.id))!.lastPositionSeconds,
        42,
      );
    },
  );

  test('malformed playlist rolls back all imported records', () async {
    snapshot['playlists'] = [
      {'id': 1, 'title': 'Invalid', 'mediaIDs': []},
    ];
    await legacy.writeAsString(jsonEncode(snapshot));
    final service = MyVlcImportService(database);
    final preview = await service.preview(legacy);
    await expectLater(service.import(preview), throwsFormatException);
    expect(await database.select(database.libraries).get(), isEmpty);
    expect(await database.select(database.items).get(), isEmpty);
    expect(await database.select(database.playbackProgress).get(), isEmpty);
  });

  test(
    'remote addresses are skipped and invalid resume positions fail before mutation',
    () async {
      snapshot['items'] = [
        {'url': 'https://example.invalid/media.mp4', 'resumeTime': 2},
      ];
      await legacy.writeAsString(jsonEncode(snapshot));
      final service = MyVlcImportService(database);
      expect((await service.preview(legacy)).warnings, isNotEmpty);
      snapshot['items'] = [
        {'url': media.uri.toString(), 'resumeTime': -1},
      ];
      await legacy.writeAsString(jsonEncode(snapshot));
      await expectLater(service.preview(legacy), throwsFormatException);
      expect(await database.select(database.items).get(), isEmpty);
    },
  );
}
