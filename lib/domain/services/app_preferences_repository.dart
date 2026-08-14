import '../../data/db/app_database.dart';
import '../models/app_preferences.dart';

class AppPreferencesRepository {
  const AppPreferencesRepository(this.database);

  final AppDatabase database;

  Future<AppPreferences> load() async {
    final values = await Future.wait([
      database.getSetting('defaultPlaybackSpeed'),
      database.getSetting('resumeRewindSeconds'),
      database.getSetting('autoAdvance'),
      database.getSetting('completionThreshold'),
    ]);
    return AppPreferences(
      defaultPlaybackSpeed: _double(
        values[0],
        fallback: 1,
        minimum: 0.5,
        maximum: 2,
      ),
      resumeRewindSeconds: _double(
        values[1],
        fallback: 10,
        minimum: 0,
        maximum: 30,
      ),
      autoAdvance: _bool(values[2], fallback: true),
      completionThreshold: _double(
        values[3],
        fallback: 0.90,
        minimum: 0.5,
        maximum: 1,
      ),
    );
  }

  Future<void> save(AppPreferences preferences) async {
    await database.transaction(() async {
      await database.setSetting(
        'defaultPlaybackSpeed',
        preferences.defaultPlaybackSpeed.toString(),
      );
      await database.setSetting(
        'resumeRewindSeconds',
        preferences.resumeRewindSeconds.toString(),
      );
      await database.setSetting(
        'autoAdvance',
        preferences.autoAdvance.toString(),
      );
      await database.setSetting(
        'completionThreshold',
        preferences.completionThreshold.toString(),
      );
    });
  }

  double _double(
    String? value, {
    required double fallback,
    required double minimum,
    required double maximum,
  }) {
    return (double.tryParse(value ?? '') ?? fallback).clamp(minimum, maximum);
  }

  bool _bool(String? value, {required bool fallback}) => switch (value) {
    'true' => true,
    'false' => false,
    _ => fallback,
  };
}
