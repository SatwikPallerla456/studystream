import 'dart:convert';

/// Per-entity Lamport revisions. Wall clocks are activity/display facts only.
/// Device and operation identity make concurrent edits deterministic.
abstract final class SyncIntent {
  static const zero = [0, '', ''];
  static const maxClock = 9007199254740990;
  static List<dynamic> stamp(Object? raw) {
    if (raw is! List ||
        raw.length != 3 ||
        raw[0] is! int ||
        raw[0] < 0 ||
        raw[0] > maxClock ||
        raw[1] is! String ||
        raw[2] is! String ||
        (raw[1] as String).length > 512 ||
        (raw[2] as String).length > 128)
      throw const FormatException('Invalid sync revision');
    return List.of(raw);
  }

  static int compare(Object? a, Object? b) {
    final x = stamp(a), y = stamp(b);
    final n = (x[0] as int).compareTo(y[0] as int);
    if (n != 0) return n;
    final d = (x[1] as String).compareTo(y[1] as String);
    return d != 0 ? d : (x[2] as String).compareTo(y[2] as String);
  }

  static bool equal(Object? a, Object? b) => compare(a, b) == 0;
  static int maximum(Map state) => ['epoch', 'position', 'completion', 'sample']
      .map((k) => stamp(state[k])[0] as int)
      .fold(state['clock'] as int? ?? 0, (a, b) => a > b ? a : b);
  static Map<String, dynamic> legacy(Map<String, dynamic> row) {
    final time = (row['lastEventAt'] as num? ?? 0).toInt().clamp(
          0,
          maxClock - 1,
        ),
        device = (row['deviceId'] as String? ?? '');
    final legacy = [time, device, 'legacy'];
    return {
      'v': 1,
      'epoch': zero,
      'position': zero,
      'completion': row['manualCompletion'] == null ? zero : legacy,
      'policy': row['manualCompletion'],
      'sample': legacy,
      'auto': row['completed'] == true && row['manualCompletion'] == null,
    };
  }

  static Map<String, dynamic> state(Map<String, dynamic> row) {
    final raw = row['syncProgress'];
    if (raw == null) return legacy(row);
    if (raw is! Map ||
        raw['v'] != 1 ||
        raw['policy'] != null && raw['policy'] is! bool ||
        raw['auto'] is! bool)
      throw const FormatException('Unsupported progress sync state');
    final observed = raw['clock'] ?? 0;
    if (observed is! int || observed < 0 || observed > maxClock)
      throw const FormatException('Invalid observed revision');
    return {
      'v': 1,
      'clock': observed,
      for (final k in ['epoch', 'position', 'completion', 'sample'])
        k: stamp(raw[k]),
      'policy': raw['policy'],
      'auto': raw['auto'],
    };
  }

  static bool fenced(Map state) => [
    'epoch',
    'position',
    'completion',
  ].any((k) => stamp(state[k])[2] != '' && stamp(state[k])[2] != 'legacy');
  static bool samePositionContext(Map a, Map b) =>
      equal(a['epoch'], b['epoch']) && equal(a['position'], b['position']);
  static String canonical(Object? value) {
    Object? normalize(Object? v) {
      if (v is Map) {
        final keys = v.keys.cast<String>().toList()..sort();
        return {for (final k in keys) k: normalize(v[k])};
      }
      if (v is List) return v.map(normalize).toList();
      return v;
    }

    return jsonEncode(normalize(value));
  }

  /// Combines independent dimensions. Only samples from the selected reset epoch
  /// contribute furthest progress; the selected position fence owns last position.
  static Map<String, dynamic> merge(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final x = state(a), y = state(b);
    if (a['syncProgress'] != null && b['syncProgress'] == null && fenced(x))
      return {
        ...a,
        'lastOpenedAt': _max(a['lastOpenedAt'], b['lastOpenedAt']),
        'syncProgress': {
          ...x,
          'clock': maximum(x) > maximum(y) ? maximum(x) : maximum(y),
        },
      };
    if (b['syncProgress'] != null && a['syncProgress'] == null && fenced(y))
      return {
        ...b,
        'lastOpenedAt': _max(a['lastOpenedAt'], b['lastOpenedAt']),
        'syncProgress': {
          ...y,
          'clock': maximum(x) > maximum(y) ? maximum(x) : maximum(y),
        },
      };
    final epoch = compare(x['epoch'], y['epoch']);
    final candidates = epoch > 0
        ? [a]
        : epoch < 0
        ? [b]
        : [a, b];
    Map<String, dynamic> newer(
      Map<String, dynamic> l,
      Map<String, dynamic> r,
      String key,
    ) {
      final ls = stamp(state(l)[key]), rs = stamp(state(r)[key]);
      if (key == 'completion') {
        if (ls[2] != '' && ls[2] != 'legacy' && rs[2] == 'legacy') return l;
        if (rs[2] != '' && rs[2] != 'legacy' && ls[2] == 'legacy') return r;
      }
      final c = compare(state(l)[key], state(r)[key]);
      return c > 0
          ? l
          : c < 0
          ? r
          : canonical(l).compareTo(canonical(r)) >= 0
          ? l
          : r;
    }

    var position = candidates.first;
    for (final row in candidates.skip(1)) {
      final c = compare(state(position)['position'], state(row)['position']);
      position = c > 0
          ? position
          : c < 0
          ? row
          : newer(position, row, 'sample');
    }
    // Completion policy is independent of position, but belongs to this epoch.
    var policy = candidates.first;
    for (final row in candidates.skip(1))
      policy = newer(policy, row, 'completion');
    final p = state(position), c = state(policy);
    final percentKey = position.containsKey('percentWatched')
        ? 'percentWatched'
        : 'percentRead';
    final percent = candidates
        .map((r) => (r[percentKey] as num? ?? 0).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    final auto = candidates.any(
      (r) =>
          equal(state(r)['completion'], c['completion']) &&
          state(r)['auto'] == true,
    );
    final done = (c['policy'] as bool?) ?? auto;
    return {
      ...position,
      'lastOpenedAt': _max(a['lastOpenedAt'], b['lastOpenedAt']),
      'version': _max(a['version'], b['version']),
      percentKey: done ? 100.0 : percent,
      'completed': done,
      'manualCompletion': c['policy'],
      'syncProgress': {
        ...p,
        'clock': maximum(x) > maximum(y) ? maximum(x) : maximum(y),
        'completion': c['completion'],
        'policy': c['policy'],
        'auto': auto,
      },
    };
  }

  static int _max(Object? a, Object? b) {
    final x = (a as num? ?? 0).toInt(), y = (b as num? ?? 0).toInt();
    return x > y ? x : y;
  }
}
