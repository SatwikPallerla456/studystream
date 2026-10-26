import 'dart:convert';

/// Additive music fields are sent only to peers that advertise their contract.
/// Projection never deletes local state; a capability/scope change bootstraps
/// the upload again so an upgraded host receives previously withheld records.
abstract final class MusicSyncProjection {
  static const capability = 'music-metadata-v1';
  static const metadataFields = {
    'albumArtist',
    'composer',
    'lyricist',
    'label',
  };
  static Map<String, dynamic>? record(String kind, Map<String, dynamic> row) {
    if (kind == 'media_records' && row['kind'] == 'music') return null;
    if (kind == 'catalog_overrides' && metadataFields.contains(row['field']))
      return null;
    if (kind == 'embedded_tags' ||
        kind == 'media_records' && row['kind'] == 'metadata') {
      final payload = row['payload'];
      if (payload is! String) return row;
      final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      for (final key in {
        ...metadataFields,
        if (kind == 'embedded_tags') ...{'credits', 'genres', 'lyrics', 'lrc'},
      }) {
        data.remove(key);
      }
      return {...row, 'payload': jsonEncode(data)};
    }
    return row;
  }

  static Map<String, dynamic> snapshot(Map<String, dynamic> value) {
    final result = {...value};
    if (value['mediaRecords'] is List)
      result['mediaRecords'] = [
        for (final raw in value['mediaRecords'] as List)
          if (raw is Map<String, dynamic>)
            if (record('media_records', raw)
                case final Map<String, dynamic> row)
              row,
      ];
    if (value['catalogRows'] is Map)
      result['catalogRows'] = {
        for (final entry in (value['catalogRows'] as Map).entries)
          entry.key: [
            for (final raw in entry.value as List)
              if (raw is Map<String, dynamic>)
                if (record(entry.key as String, raw)
                    case final Map<String, dynamic> row)
                  row,
          ],
      };
    if (value['events'] is List)
      result['events'] = [
        for (final raw in value['events'] as List)
          if (raw is Map<String, dynamic>)
            if (raw['record'] is! Map<String, dynamic>)
              raw
            else if (record(
                  raw['entity_kind'] as String,
                  raw['record'] as Map<String, dynamic>,
                )
                case final Map<String, dynamic> row)
              {...raw, 'record': row},
      ];
    return result;
  }
}
