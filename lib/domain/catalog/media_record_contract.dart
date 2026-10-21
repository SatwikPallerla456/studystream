import 'dart:convert';
import '../reader/reader_contract.dart';
import 'catalog_online_policy.dart';

/// Version-one payloads accepted by the existing catalog and reader prototypes.
/// Backups retain extension fields, but transport exposes only declared fields.
abstract final class MediaRecordContract {
  static const maxPayloadBytes = 256 * 1024;
  static const maxRevision = 9007199254740991;
  static const _readerFields = {
    'rtl',
    'mode',
    'background',
    'fit',
    'fontSize',
    'lineHeight',
    'locator',
    'coverSingle',
    'leadingEdgeAction',
    'trailingEdgeAction',
    'topAction',
    'centerAction',
    'pairingStarts',
    'singlePages',
  };
  static const _metadataFields = {
    'title',
    'year',
    'season',
    'episode',
    'episodeEnd',
    'edition',
    'category',
    'matchState',
    'source',
    'providerId',
    'providerItemId',
    'synopsis',
    'artworkUrl',
    'sourceUrl',
    'attribution',
    'credits',
    'genres',
    'rating',
    'ratingLabel',
    'show',
    'artist',
    'album',
    'author',
    'series',
    'track',
    'disc',
    'airDate',
    'extra',
    'extraType',
  };
  static const _libraryKinds = {
    'mixed',
    'movies',
    'television',
    'music',
    'musicVideos',
    'homeVideos',
    'photos',
    'audiobooks',
    'podcasts',
    'books',
    'comics',
    'documents',
    'courses',
  };

  static Set<String> get libraryKinds => _libraryKinds;

  static Set<String>? fields(String kind) => switch (kind) {
    'library' => {'type', ..._readerFields}..remove('locator'),
    'reader' => _readerFields,
    'metadata' => _metadataFields,
    'organization' => {'favorite', 'tags'},
    'collection' || 'playlist' || 'album' => {'title', 'items'},
    _ => null,
  };

  static void identity(String value) {
    if (value.isEmpty ||
        value.length > 512 ||
        value.contains(RegExp(r'[\x00-\x1f]'))) {
      throw const FormatException('Invalid media identity');
    }
  }

  static void revision(Object? value) {
    if (value is! int || value < 0 || value > maxRevision) {
      throw const FormatException('Invalid media revision');
    }
  }

  static void validate({
    required String id,
    required String kind,
    required String libraryId,
    required String? itemId,
    required Map<String, dynamic> data,
    bool allowUnknownKind = false,
  }) {
    identity(id);
    identity(libraryId);
    identity(kind);
    if (itemId != null) identity(itemId);
    if (utf8.encode(jsonEncode(data)).length > maxPayloadBytes) {
      throw const FormatException('Metadata is too large');
    }
    void jsonValue(Object? value, int depth) {
      if (depth > 8) {
        throw const FormatException('Metadata nesting is too deep');
      }
      if (value is Map) {
        if (value.length > 200) {
          throw const FormatException('Too many metadata fields');
        }
        for (final entry in value.entries) {
          if (entry.key is! String || (entry.key as String).length > 200) {
            throw const FormatException('Invalid metadata field name');
          }
          jsonValue(entry.value, depth + 1);
        }
      } else if (value is List) {
        if (value.length > 10000) {
          throw const FormatException('Metadata list is too large');
        }
        for (final entry in value) {
          jsonValue(entry, depth + 1);
        }
      } else if (value is String) {
        if (value.length > 16000) {
          throw const FormatException('Metadata text is too long');
        }
      } else if (value != null &&
          value is! bool &&
          (value is! num || !value.isFinite)) {
        throw const FormatException('Invalid metadata value');
      }
    }

    jsonValue(data, 0);
    final declared = fields(kind);
    if (declared == null) {
      if (allowUnknownKind) {
        return; // Retained local backup extension, never hosted.
      }
      throw const FormatException('Unsupported media record kind');
    }
    final itemKind = {'reader', 'metadata', 'organization'}.contains(kind);
    if (itemKind != (itemId != null) ||
        kind == 'library' && id != 'library:$libraryId' ||
        itemKind && id != '$kind:$itemId') {
      throw const FormatException('Invalid media record ownership');
    }
    void string(String key, {int limit = 16000}) {
      final value = data[key];
      if (value != null && (value is! String || value.length > limit)) {
        throw FormatException('Invalid $kind field: $key');
      }
    }

    void number(String key, num min, num max, {bool integer = false}) {
      final value = data[key];
      if (value != null &&
          (value is! num ||
              !value.isFinite ||
              value < min ||
              value > max ||
              integer && value is! int)) {
        throw FormatException('Invalid $kind field: $key');
      }
    }

    void choice(String key, Set<String> values) {
      if (data[key] != null && !values.contains(data[key])) {
        throw FormatException('Invalid $kind field: $key');
      }
    }

    void strings(String key, int count, int length) {
      final value = data[key];
      if (value != null &&
          (value is! List ||
              value.length > count ||
              value.any(
                (v) => v is! String || v.isEmpty || v.length > length,
              ))) {
        throw FormatException('Invalid $kind field: $key');
      }
    }

    if (kind == 'library' || kind == 'reader') {
      choice('type', _libraryKinds);
      if (data['rtl'] != null && data['rtl'] is! bool) {
        throw const FormatException('Invalid reading direction');
      }
      for (final key in [
        'leadingEdgeAction',
        'trailingEdgeAction',
        'topAction',
        'centerAction',
      ]) {
        choice(key, ReaderTapPolicy.actions);
      }
      choice('mode', {'horizontal', 'spread', 'vertical'});
      choice('background', {'black', 'white', 'color', 'immersive'});
      choice('fit', {'contain', 'fitWidth', 'fill'});
      if (data['coverSingle'] != null && data['coverSingle'] is! bool)
        throw const FormatException('Invalid cover setting');
      for (final key in ['pairingStarts', 'singlePages']) {
        final value = data[key];
        if (value != null &&
            (value is! List ||
                value.length > 10000 ||
                value.any((v) => v is! int || v < 1 || v > 10000)))
          throw const FormatException('Invalid pairing override');
      }
      number('fontSize', 12, 36);
      number('lineHeight', 1.2, 2.4);
      string('locator', limit: 4096);
    } else if (kind == 'metadata') {
      if (data['artworkUrl'] != null &&
          !CatalogOnlinePolicy.artwork(
            data['artworkUrl'] is String ? data['artworkUrl'] : null,
          )) {
        throw const FormatException('Invalid catalog artwork URL');
      }
      if (data['sourceUrl'] != null &&
          !CatalogOnlinePolicy.source(
            data['sourceUrl'] is String ? data['sourceUrl'] : null,
          )) {
        throw const FormatException('Invalid catalog source URL');
      }
      for (final key in _metadataFields.difference({
        'year',
        'season',
        'episode',
        'episodeEnd',
        'rating',
        'track',
        'disc',
        'extra',
      })) {
        string(key);
      }
      number('year', 0, 9999, integer: true);
      number('season', 0, 100000, integer: true);
      number('episode', 0, 100000, integer: true);
      number('episodeEnd', 0, 100000, integer: true);
      if (data['episodeEnd'] != null &&
          data['episode'] != null &&
          (data['episodeEnd'] < data['episode'] ||
              data['episodeEnd'] - data['episode'] >= 32)) {
        throw const FormatException('Invalid episode range');
      }
      choice('category', _libraryKinds);
      choice('extraType', {
        'behindScenes',
        'deletedScene',
        'featurette',
        'interview',
        'scene',
        'short',
        'trailer',
        'other',
      });
      number('rating', 0, 100);
      number('track', 0, 100000, integer: true);
      number('disc', 0, 100000, integer: true);
      if (data['extra'] != null && data['extra'] is! bool)
        throw const FormatException('Invalid extra flag');
      choice('matchState', {'unmatched', 'matched', 'cleared'});
    } else if (kind == 'organization') {
      if (data['favorite'] != null && data['favorite'] is! bool) {
        throw const FormatException('Invalid favorite flag');
      }
      strings('tags', 100, 200);
    } else {
      string('title', limit: 200);
      if (data['title'] is! String ||
          (data['title'] as String).trim().isEmpty ||
          data['items'] is! List) {
        throw const FormatException('A collection needs a title and item list');
      }
      strings('items', 10000, 512);
    }
  }

  /// Unknown extension fields remain local; they can contain paths or secrets.
  static Map<String, dynamic>? forTransport(Map<String, dynamic> row) {
    try {
      final kind = row['kind'] as String;
      final declared = fields(kind);
      if (declared == null) return null;
      final data = Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String) as Map,
      );
      validate(
        id: row['id'] as String,
        kind: kind,
        libraryId: row['library_id'] as String,
        itemId: row['item_id'] as String?,
        data: data,
      );
      if (kind == 'reader' && data['locator'] is String) {
        final locator = ReaderLocator.decode(data['locator'] as String);
        if (locator == null ||
            locator.resourceId != row['item_id'] ||
            locator.pageKey.startsWith('/') ||
            locator.pageKey.contains('\\') ||
            locator.pageKey.split('/').contains('..')) {
          data.remove('locator');
        } else {
          data['locator'] = ReaderLocator(
            resourceId: locator.resourceId,
            revision: locator.revision,
            pageKey: locator.pageKey,
            page: locator.page,
            point: locator.point,
            fit: locator.fit,
            zoom: locator.zoom,
            textOffset: locator.textOffset,
          ).encode();
        }
      }
      return {
        ...row,
        'payload': jsonEncode({
          for (final key in declared)
            if (data.containsKey(key)) key: data[key],
        }),
      };
    } on Object {
      // A legacy/unrecognized record cannot make a valid library inaccessible.
      return null;
    }
  }
}
