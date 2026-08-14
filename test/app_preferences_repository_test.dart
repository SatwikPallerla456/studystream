import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/domain/models/app_preferences.dart';
import 'package:study_stream/domain/services/app_preferences_repository.dart';

void main() {
  test(
    'persists typed playback preferences and validates stored values',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = AppPreferencesRepository(database);

      final defaults = await repository.load();
      expect(defaults.defaultPlaybackSpeed, 1);
      expect(defaults.resumeRewindSeconds, 10);
      expect(defaults.autoAdvance, isTrue);
      expect(defaults.completionThreshold, 0.90);

      const expected = AppPreferences(
        defaultPlaybackSpeed: 1.5,
        resumeRewindSeconds: 15,
        autoAdvance: false,
        completionThreshold: 0.85,
      );
      await repository.save(expected);
      final restored = await repository.load();
      expect(restored.defaultPlaybackSpeed, 1.5);
      expect(restored.resumeRewindSeconds, 15);
      expect(restored.autoAdvance, isFalse);
      expect(restored.completionThreshold, 0.85);

      await database.setSetting('defaultPlaybackSpeed', '99');
      await database.setSetting('resumeRewindSeconds', '-5');
      await database.setSetting('completionThreshold', 'invalid');
      final validated = await repository.load();
      expect(validated.defaultPlaybackSpeed, 2);
      expect(validated.resumeRewindSeconds, 0);
      expect(validated.completionThreshold, 0.90);
    },
  );
}
