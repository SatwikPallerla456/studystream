import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/sync/sync_snapshot_merger.dart';
import 'package:study_stream/domain/catalog/media_catalog_repository.dart';

import 'fixtures/tangerine_preservation_fixture.dart';

void main() {
  test(
    'P0 disk reopen and repeated backups preserve resource and Study identities',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'tangerine-preservation-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final file = File('${temporary.path}/fixture.sqlite');
      final db = AppDatabase.forTesting(NativeDatabase(file));
      await seedTangerinePreservation(
        db,
        legacyRoot: '/fixture/missing',
        secondaryRoot: '/fixture/secondary',
      );
      final before = await db.exportData();
      await db.close();
      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(reopened.close);
      final after = await reopened.exportData();
      for (final key in [
        'libraries',
        'sections',
        'items',
        'playback',
        'reading',
        'notes',
        'bookmarks',
        'sources',
        'mediaRecords',
        'settings',
      ]) {
        expect(
          after[key],
          before[key],
          reason: 'Disk reopen must preserve $key',
        );
      }
      final restored = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(restored.close);
      await restored.importData(
        jsonDecode(jsonEncode(before)) as Map<String, dynamic>,
      );
      await restored.importData(
        jsonDecode(jsonEncode(before)) as Map<String, dynamic>,
      );
      final roundTrip = await restored.exportData();
      for (final key in [
        'libraries',
        'sections',
        'items',
        'playback',
        'reading',
        'notes',
        'bookmarks',
        'sources',
        'mediaRecords',
      ]) {
        expect(
          roundTrip[key],
          before[key],
          reason: 'Repeated backup import must preserve $key',
        );
      }
      for (final key in [
        'myvlc.queue',
        'myvlc.playlists',
        'player.item.local-video',
      ]) {
        expect(await restored.getSetting(key), await reopened.getSetting(key));
      }
      expect(
        (await restored.getReadingByItemId('local-book'))?.manualCompletion,
        true,
      );
      expect(
        (await restored.getPlaybackByItemId(
          'local-video',
        ))?.resumePositionSeconds,
        42,
      );
    },
  );

  test(
    'media import rejects ownership changes and rolls back preceding writes',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seedTangerinePreservation(
        db,
        legacyRoot: '/fixture/missing',
        secondaryRoot: '/fixture/secondary',
      );
      final rows = await db.exportMediaRows('media_records');
      final original = rows.firstWhere(
        (r) => r['id'] == 'metadata:local-video',
      );
      final foreign = rows.firstWhere(
        (r) => r['id'] == 'metadata:mirror-video',
      );
      final valid = {
        ...original,
        'payload': jsonEncode({'title': 'Should roll back'}),
        'updated_at': (original['updated_at'] as int) + 1,
      };
      final stolen = {
        ...foreign,
        'id': original['id'],
        'updated_at': (original['updated_at'] as int) + 2,
      };
      await expectLater(
        db.importMediaRows({
          'mediaRecords': [valid, stolen],
        }),
        throwsFormatException,
      );
      expect(
        (await MediaCatalogRepository(
          db,
        ).record(original['id'] as String))?.data['title'],
        'local catalog title',
      );
      await expectLater(
        db.importMediaRows({
          'mediaRecords': [
            {
              ...original,
              'kind': 'reader',
              'payload': '{}',
              'updated_at': (original['updated_at'] as int) + 3,
            },
          ],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'payload schemas, membership, byte bounds and revision ordering are enforced',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seedTangerinePreservation(
        db,
        legacyRoot: '/fixture/missing',
        secondaryRoot: '/fixture/secondary',
      );
      final catalog = MediaCatalogRepository(db);
      final original = (await db.exportMediaRows(
        'media_records',
      )).firstWhere((r) => r['id'] == 'reader:local-book');
      for (final patch in [
        {'payload': '[]'},
        {'payload': '{broken'},
        {
          'payload': jsonEncode({'rtl': 'false'}),
        },
        {
          'payload': jsonEncode({'fontSize': 100}),
        },
        {'updated_at': -1},
        {'deleted': 3},
        {
          'payload': jsonEncode({'extension': List.filled(16000, '🟠').join()}),
        },
      ]) {
        await expectLater(
          db.importMediaRows({
            'mediaRecords': [
              {...original, ...patch},
            ],
          }),
          throwsFormatException,
        );
      }
      await expectLater(
        catalog.save('foreign-collection', 'collection', 'local', {
          'title': 'Foreign',
          'items': ['mirror-video'],
        }),
        throwsFormatException,
      );
      await db.importMediaRows({
        'mediaRecords': [
          {...original, 'updated_at': 0, 'payload': '{}'},
        ],
      });
      expect(
        (await catalog.record('reader:local-book'))?.data['locator'],
        'chapter-6',
      );
      await catalog.save('reader:local-book', 'reader', 'local', {
        'rtl': false,
        'fontSize': 20,
      }, itemId: 'local-book');
      final first = (await catalog.record('reader:local-book'))!.updatedAt;
      await catalog.save('reader:local-book', 'reader', 'local', {
        'rtl': false,
        'fontSize': 22,
      }, itemId: 'local-book');
      expect(
        (await catalog.record('reader:local-book'))!.updatedAt,
        greaterThan(first),
      );
    },
  );

  test(
    'scoped sync blocks forged ownership and preserves local source permissions',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seedTangerinePreservation(
        db,
        legacyRoot: '/fixture/missing',
        secondaryRoot: '/fixture/secondary',
      );
      final before = await db.exportData();
      final notes = (before['notes'] as List).cast<Map<String, dynamic>>();
      final localNote = notes.firstWhere((r) => r['id'] == 'local-note');
      final mirrorNote = notes.firstWhere((r) => r['id'] == 'mirror-note');
      await expectLater(
        SyncSnapshotMerger(db).merge(
          {
            'schemaVersion': db.schemaVersion,
            'notes': [
              {...localNote, 'content': 'Rollback', 'updatedAt': 100},
              {
                ...mirrorNote,
                'libraryId': 'local',
                'itemId': 'local-book',
                'updatedAt': 101,
              },
            ],
          },
          allowedLibraryIds: {'local'},
        ),
        throwsFormatException,
      );
      expect(
        (await db.watchNotes(itemId: 'local-book').first).single.content,
        'local page note',
      );
      await SyncSnapshotMerger(db).merge(
        {
          ...before,
          'libraries': [
            (before['libraries'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((r) => r['id'] == 'mirror')
              ..['title'] = 'Forbidden',
          ],
          'sources': [
            {
              'id': 'secondary',
              'library_id': 'local',
              'root_path': '/outside',
              'namespace': '@sources/secondary',
              'unavailable': 0,
              'updated_at': 9999999999999,
            },
          ],
        },
        allowedLibraryIds: {'local'},
      );
      expect((await db.getLibraryById('mirror'))?.title, 'mirror library');
      expect(
        (await MediaCatalogRepository(
          db,
        ).sources('local')).firstWhere((s) => s.id == 'secondary').root,
        '/fixture/secondary',
      );
      expect(await db.getSetting('sync.fixturePermission'), '/fixture/missing');
    },
  );
}
