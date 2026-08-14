import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/domain/services/sync_conflict_resolver.dart';

void main() {
  test('keeps the furthest automatic progress', () {
    final merged = SyncConflictResolver.mergeProgress(
      {
        'percentWatched': 40.0,
        'completed': false,
        'lastEventAt': 20,
        'version': 2,
        'deviceId': 'desktop',
      },
      {
        'percentWatched': 65.0,
        'completed': false,
        'lastEventAt': 10,
        'version': 1,
        'deviceId': 'phone',
      },
    );
    expect(merged['percentWatched'], 65.0);
  });

  test('manual completion wins over automatic progress', () {
    final merged = SyncConflictResolver.mergeProgress(
      {
        'percentWatched': 90.0,
        'completed': true,
        'manualCompletion': null,
        'lastEventAt': 20,
      },
      {
        'percentWatched': 20.0,
        'completed': false,
        'manualCompletion': false,
        'lastEventAt': 10,
      },
    );
    expect(merged['completed'], isFalse);
    expect(merged['manualCompletion'], isFalse);
  });

  test('preserves both conflicting note bodies', () {
    final values = SyncConflictResolver.preserveUserContentConflict(
      {
        'id': 'note',
        'content': 'Desktop edit',
        'updatedAt': 20,
        'version': 2,
        'deviceId': 'desktop',
      },
      {
        'id': 'note',
        'content': 'Phone edit',
        'updatedAt': 21,
        'version': 2,
        'deviceId': 'phone',
      },
    );
    expect(values, hasLength(2));
    expect(
      values.map((value) => value['content']),
      containsAll(['Desktop edit', 'Phone edit']),
    );
    expect(values.map((value) => value['id']).toSet(), hasLength(2));
  });
}
