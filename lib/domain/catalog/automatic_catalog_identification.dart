import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import 'catalog_hints.dart';
import 'catalog_identity_store.dart';
import 'catalog_match_policy.dart';
import 'media_catalog_repository.dart';
import 'online_catalog_provider.dart';

/// Conservative online work owned by the existing, pausable processing queue.
class AutomaticCatalogIdentification {
  const AutomaticCatalogIdentification(this.db);
  final AppDatabase db;
  static const version = 2;
  static String setting(String libraryId) =>
      'identification.enabled:$libraryId';
  static String _identity(Map<String, dynamic> data) => jsonEncode({
    for (final field in [
      'title',
      'show',
      'year',
      'season',
      'episode',
      'episodeEnd',
      'category',
      'extra',
    ])
      field: data[field],
  });

  Future<({String state, String? reason})> run(
    Item item, {
    required bool Function() isCurrent,
  }) async {
    final store = CatalogIdentityStore(db),
        catalog = MediaCatalogRepository(db);
    // Both selected and explicitly cleared matches are durable user decisions.
    if (await store.decision(item.id) != null)
      return (state: 'complete', reason: 'decisionKept');
    if (await db.getSetting(setting(item.libraryId)) == 'false')
      return (state: 'queued', reason: null);
    final data = await catalog.metadata(item),
        hints = CatalogHints.filename(item.filename);
    final library = await catalog.libraryKind(item.libraryId);
    final category = library == LibraryKind.mixed
        ? data['category']
        : library.name;
    if (item.itemType != 'video' ||
        !{'movies', 'television'}.contains(category) ||
        data['extra'] == true ||
        hints['extra'] == true) {
      return (state: 'unsupported', reason: 'categoryUnsupported');
    }
    final television = category == 'television';
    if (television &&
        (data['season'] is! int ||
            data['episode'] is! int ||
            hints['episodeRangeIssue'] != null)) {
      return (state: 'review', reason: 'episodeNeeded');
    }
    final before = await File(item.filePath).stat();
    if (before.type != FileSystemEntityType.file ||
        (item.fileSize != null && before.size != item.fileSize) ||
        (item.modifiedAt != null &&
            before.modified.millisecondsSinceEpoch != item.modifiedAt)) {
      throw const FileSystemException('Source changed or unavailable');
    }
    final explicit = hints['explicitProvider'] == 'tvdb'
        ? '${hints['explicitId']}'
        : '';
    final title =
        '${television ? data['show'] ?? data['title'] : data['title'] ?? ''}'
            .trim();
    final year = data['year'] is int ? data['year'] as int : null;
    final provider = OnlineCatalogProvider('tvdb');
    Map<String, dynamic>? hit;
    Map<String, dynamic>? verifiedDetails;
    if (RegExp(r'^[1-9][0-9]*$').hasMatch(explicit)) {
      hit = {
        'id': '${television ? 'series' : 'movie'}/$explicit',
        '_matchReason': 'Explicit TheTVDB ID in filename',
      };
    } else {
      if (title.length < 3 || year == null)
        return (state: 'review', reason: 'identityNeeded');
      final hits = await provider.search(
        title,
        year: year,
        type: television ? 'episode' : 'movie',
      );
      if (!isCurrent()) return (state: 'queued', reason: null);
      hit = CatalogMatchPolicy.automatic(title, year, hits);
      if (hit == null &&
          !television &&
          !hits.any(
            (candidate) =>
                CatalogMatchPolicy.exactTitle(title, candidate) &&
                candidate['year'] == year,
          )) {
        final adjacent = await TvdbCatalogSession.adjacentMovieCandidates(
          title,
          year,
        );
        final verified = <Map<String, dynamic>>[];
        if (adjacent != null) {
          for (final candidate in adjacent) {
            if (!isCurrent()) return (state: 'queued', reason: null);
            final detail = await provider.details(candidate);
            if ((detail['_releaseYears'] as List?)?.contains(year) == true)
              verified.add(detail);
          }
          if (verified.length == 1) {
            verifiedDetails = verified.single;
            final premiere = verifiedDetails['year'];
            verifiedDetails['year'] = year;
            verifiedDetails['_matchReason'] =
                'Exact title and verified $year release; provider premiere $premiere';
            hit = verifiedDetails;
          }
        }
      }
      if (hit == null)
        return (
          state: 'review',
          reason: hits.isEmpty ? 'noMatch' : 'ambiguous',
        );
      if (verifiedDetails == null)
        hit['_matchReason'] = 'Unique normalized title or alias and exact year';
    }
    if (!isCurrent()) return (state: 'queued', reason: null);
    final details =
        verifiedDetails ??
        await provider.details(
          hit,
          season: television ? data['season'] as int : null,
          episode: television ? data['episode'] as int : null,
          episodeEnd: television ? data['episodeEnd'] as int? : null,
        );
    final after = await File(item.filePath).stat();
    if (after.type != before.type ||
        after.size != before.size ||
        after.modified != before.modified) {
      throw const FileSystemException('Source changed during identification');
    }
    var applied = false;
    await db.transaction(() async {
      final current = await db.getItemById(item.id);
      if (!isCurrent() ||
          current == null ||
          current.unavailable ||
          current.filePath != item.filePath ||
          current.fingerprint != item.fingerprint ||
          current.modifiedAt != item.modifiedAt ||
          current.fileSize != item.fileSize ||
          await db.getSetting(setting(item.libraryId)) == 'false')
        return;
      final offline = await db
          .customSelect(
            'SELECT 1 FROM item_assets a JOIN library_sources s ON s.id=a.source_id WHERE a.item_id=? AND s.unavailable=1 LIMIT 1',
            variables: [Variable(item.id)],
          )
          .getSingleOrNull();
      if (offline != null || await store.decision(item.id) != null) return;
      if (_identity(await catalog.metadata(current)) != _identity(data)) return;
      await store.select(
        current,
        details,
        providerId: 'tvdb',
        expectedRevision: 0,
        origin: 'automatic',
      );
      applied = true;
    });
    return (state: applied ? 'complete' : 'queued', reason: null);
  }
}
