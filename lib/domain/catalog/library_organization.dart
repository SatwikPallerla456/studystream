import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../../data/db/app_database.dart';
import '../../data/indexer/embedded_audio_tags.dart';
import '../../data/reader/safe_book_archive.dart';
import 'catalog_hints.dart';
import 'catalog_identity_store.dart';
import 'media_catalog_repository.dart';
import 'media_probe.dart';

/// Derived local metadata is replaceable. User overrides and matches stay above it.
class LibraryOrganization {
  const LibraryOrganization(this.db);
  final AppDatabase db;
  static const version = 2;
  Future<void> organize(Item item, {required bool Function() isCurrent}) async {
    final before = await File(item.filePath).stat();
    if (before.type != FileSystemEntityType.file ||
        (item.fileSize != null && before.size != item.fileSize) ||
        (item.modifiedAt != null &&
            before.modified.millisecondsSinceEpoch != item.modifiedAt))
      throw const FileSystemException('Source changed or is unavailable');
    final tags = <String, dynamic>{};
    if (item.itemType == 'audio')
      tags.addAll(await EmbeddedAudioTags.read(File(item.filePath)));
    if (item.itemType == 'audio' &&
        !{'mp3', 'flac'}.contains(
          p.extension(item.filename).toLowerCase().replaceFirst('.', ''),
        )) {
      final probe = await MediaProbe.read(item);
      if (probe['tags'] case final Map values)
        tags.addAll(Map<String, dynamic>.from(values));
    }
    if ({'epub', 'cbz'}.contains(item.itemType)) {
      final archive = await SafeBookArchive.open(item.filePath);
      String? package;
      if (item.itemType == 'epub') {
        final container = XmlDocument.parse(
          await archive.text('META-INF/container.xml'),
        );
        package = container.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'rootfile')
            .firstOrNull
            ?.getAttribute('full-path');
      } else {
        package = archive.entries.keys
            .where((name) => name.toLowerCase() == 'comicinfo.xml')
            .firstOrNull;
      }
      if (package != null) {
        final xml = XmlDocument.parse(await archive.text(package));
        String? field(String key) {
          final text = xml.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local.toLowerCase() == key.toLowerCase())
              .firstOrNull
              ?.innerText
              .trim();
          return text == null ||
                  text.isEmpty ||
                  text.length > 512 ||
                  text.contains(RegExp(r'[\x00-\x1f]'))
              ? null
              : text;
        }

        for (final entry in {
          'title': 'title',
          'author': item.itemType == 'epub' ? 'creator' : 'writer',
          'series': 'series',
        }.entries) {
          final text = field(entry.value);
          if (text != null) tags[entry.key] = text;
        }
        if (item.itemType == 'cbz') {
          final volume = int.tryParse(field('volume') ?? '');
          final chapter = num.tryParse(field('number') ?? '');
          if (volume != null && volume >= 0 && volume <= 100000)
            tags['volume'] = volume;
          if (chapter != null &&
              chapter.isFinite &&
              chapter >= 0 &&
              chapter <= 100000)
            tags['chapter'] = chapter;
        }
      }
    }
    final metadata = await MediaCatalogRepository(db).metadata(item);
    if ({'audiobooks', 'podcasts'}.contains(metadata['category'])) {
      if (tags['artist'] != null) tags['author'] = tags['artist'];
      if (tags['album'] != null) tags['series'] = tags['album'];
    }
    if (metadata['category'] == 'musicVideos' && tags['artist'] == null) {
      final match = RegExp(
        r'^(.{1,120}?) - (.{1,200})$',
      ).firstMatch(p.basenameWithoutExtension(item.filename));
      if (match != null)
        tags.addAll({'artist': match[1]!.trim(), 'title': match[2]!.trim()});
    }
    final after = await File(item.filePath).stat();
    if (!isCurrent()) throw const FormatException('Organization cancelled');
    if (after.type != FileSystemEntityType.file ||
        after.size != before.size ||
        after.modified != before.modified)
      throw const FileSystemException(
        'Organization source changed or unavailable',
      );
    await db.transaction(() async {
      final current = await db.getItemById(item.id);
      if (!isCurrent() ||
          current == null ||
          current.filePath != item.filePath ||
          current.fingerprint != item.fingerprint ||
          current.modifiedAt != item.modifiedAt ||
          current.unavailable)
        throw const FormatException('Organization source changed');
      await db.customStatement(
        'INSERT INTO embedded_tags(id,library_id,item_id,content_revision,payload,updated_at) VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET content_revision=excluded.content_revision,payload=excluded.payload,updated_at=excluded.updated_at',
        [
          item.id,
          item.libraryId,
          item.id,
          item.fingerprint ?? 'legacy:${item.fileSize}:${item.modifiedAt}',
          jsonEncode(tags),
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      await CatalogIdentityStore(db).reindex(current);
      await _suggest(current);
    });
  }

  Future<void> _suggest(Item item) async {
    await db.customStatement(
      'DELETE FROM processing_suggestions WHERE item_id=? AND dismissed=0',
      [item.id],
    );
    final kind = CatalogHints.extraKind(item.relativePath);
    String? target, reason;
    if (kind != null && item.itemType == 'video') {
      // A prior manual association/tombstone is an explicit decision.
      if (await db
              .customSelect(
                'SELECT id FROM media_extras WHERE item_id=? LIMIT 1',
                variables: [Variable(item.id)],
              )
              .getSingleOrNull() !=
          null)
        return;
      var folder = p.posix.dirname(item.relativePath.replaceAll('\\', '/'));
      if (CatalogHints.extraFolders.containsKey(
        p.posix.basename(folder).toLowerCase(),
      ))
        folder = p.posix.dirname(folder);
      if (folder == '.') folder = '';
      final candidates = await db
          .customSelect(
            '''SELECT i.id FROM items i JOIN catalog_facets f ON f.item_id=i.id AND f.field='folder'
        WHERE i.library_id=? AND i.item_type='video' AND i.id<>? AND f.value=?
        AND NOT EXISTS(SELECT 1 FROM catalog_facets x WHERE x.item_id=i.id AND x.field='extra' AND x.value='true')
        AND NOT EXISTS(SELECT 1 FROM media_extras e WHERE e.item_id=i.id AND e.deleted=0)
        ORDER BY i.id LIMIT 2''',
            variables: [
              Variable(item.libraryId),
              Variable(item.id),
              Variable(folder),
            ],
          )
          .get();
      if (candidates.length == 1)
        target = candidates.single.data['id'] as String;
      reason = target == null ? 'extraAmbiguous' : 'extraCandidate';
    } else if ({'audio', 'video'}.contains(item.itemType) &&
        CatalogHints.filename(item.filename)['part'] != null) {
      if (await db
              .customSelect(
                'SELECT id FROM media_parts WHERE (item_id=? OR representation_id=?) LIMIT 1',
                variables: [Variable(item.id), Variable(item.id)],
              )
              .getSingleOrNull() !=
          null)
        return;
      target = item.id;
      reason = 'multipartCandidate';
    }
    if (reason != null)
      await db.customStatement(
        'INSERT OR IGNORE INTO processing_suggestions(item_id,library_id,target_id,reason,dismissed) VALUES(?,?,?,?,0)',
        [item.id, item.libraryId, target, reason],
      );
  }
}
