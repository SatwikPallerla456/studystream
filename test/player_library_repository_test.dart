import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/domain/services/player_library_repository.dart';
import 'package:study_stream/domain/services/player_controls_repository.dart';
import 'package:study_stream/domain/services/player_profile_repository.dart';

void main() {
  late AppDatabase db;
  late PlayerLibraryRepository repository;
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('tangerine-playlists-');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PlayerLibraryRepository(db);
    await db.upsertLibrary(
      LibrariesCompanion.insert(
        id: 'l',
        title: 'Media',
        rootFolderPath: root.path,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await db.upsertSection(
      SectionsCompanion.insert(
        id: 's',
        libraryId: 'l',
        title: 'Media',
        orderIndex: 0,
        folderPath: root.path,
      ),
    );
    for (var i = 0; i < 3; i++) {
      await db.upsertItem(
        ItemsCompanion.insert(
          id: '$i',
          libraryId: 'l',
          sectionId: 's',
          title: 'Media $i',
          filename: '$i.mp3',
          filePath: '${root.path}/$i.mp3',
          relativePath: '$i.mp3',
          itemType: 'audio',
          orderIndex: i,
        ),
      );
    }
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });
  test(
    'legacy queue IDs are stable and removed imported playlists stay removed after reimport',
    () async {
      await db.setSetting('myvlc.queue', jsonEncode(['0', '1', '0']));
      await db.setSetting(
        'myvlc.playlists',
        jsonEncode({
          'p': {
            'id': 'p',
            'title': 'Imported',
            'itemIds': ['0', '1'],
          },
        }),
      );
      final first = await repository.load(), second = await repository.load();
      expect(first.queue.map((e) => e.id), second.queue.map((e) => e.id));
      await repository.select(first.queue[1].id);
      expect((await repository.load()).current!.itemId, '1');
      await repository.deletePlaylist('p');
      await db.setSetting(
        'myvlc.playlists',
        jsonEncode({
          'p': {
            'id': 'p',
            'title': 'Imported',
            'itemIds': ['0'],
          },
        }),
      );
      expect((await repository.load()).playlists, isEmpty);
    },
  );
  test(
    'queue repeat, manual advance, duplicates and shuffled order survive reload and backup',
    () async {
      await repository.setQueue(['0', '1', '0', '2']);
      await repository.setRepeat(QueueRepeat.one);
      expect(
        await repository.advance(currentItemId: '0', automatic: true),
        '0',
      );
      expect(await repository.advance(currentItemId: '0'), '1');
      await repository.setShuffle(true, random: Random(2));
      var state = await repository.load();
      expect(state.current!.itemId, '1');
      expect(state.playOrder.toSet().length, 4);
      await repository.reorder(0, 4);
      expect((await repository.load()).current!.itemId, '1');
      final snapshot = await db.exportData();
      final restored = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(restored.close);
      await restored.importData(snapshot);
      final reopened = await PlayerLibraryRepository(restored).load();
      expect(reopened.currentEntryId, state.currentEntryId);
      expect(reopened.shuffle, true);
      expect(reopened.queue.map((e) => e.itemId), ['1', '0', '2', '0']);
    },
  );
  test(
    'M3U and PLS preserve ordering and duplicates and report unresolved streams',
    () async {
      final m3u = await File('${root.path}/My list.m3u8').writeAsString(
        '\uFEFF#EXTM3U\n#EXTINF:-1,First\n1.mp3\n0.mp3\n1.mp3\nhttps://example.invalid/private\n',
      );
      final preview = await repository.previewPlaylist(m3u);
      expect(preview.itemIds, ['1', '0', '1']);
      expect(preview.unmatched.length, 1);
      final pls = await File(
        '${root.path}/Order.pls',
      ).writeAsString('[playlist]\nFile10=2.mp3\nFile2=0.mp3\nFile1=1.mp3\n');
      expect((await repository.previewPlaylist(pls)).itemIds, ['1', '0', '2']);
      final id = await repository.savePlaylist('Saved', preview.itemIds);
      final playlist = (await repository.load()).playlists.singleWhere(
        (v) => v.id == id,
      );
      final exported = await repository.exportM3u(playlist);
      expect(exported, contains(Uri.file('${root.path}/1.mp3').toString()));
      expect(exported, isNot(contains('https://')));
    },
  );
  test(
    'shortcut conflicts roll back and profiles preserve pairing isolation',
    () async {
      final controls = PlayerControlsRepository(db),
          profiles = PlayerProfileRepository(db);
      await controls.save(
        PlayerControls(
          local: {'playPause': 'Control+K'},
          global: {'playPause': 'Control+Shift+K'},
        ),
      );
      await db.setSetting('sync.allowPlaybackControl', 'false');
      final id = await profiles.save('Quiet controls');
      await controls.save(PlayerControls(local: {'playPause': 'Alt+K'}));
      await db.setSetting('sync.allowPlaybackControl', 'true');
      await profiles.apply(id);
      expect((await controls.load()).local['playPause'], 'Control+K');
      expect(await db.getSetting('sync.allowPlaybackControl'), 'true');
      await expectLater(
        controls.save(PlayerControls(local: {'playPause': 'M'})),
        throwsFormatException,
      );
      expect((await controls.load()).local['playPause'], 'Control+K');
    },
  );
}
