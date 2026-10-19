import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../data/db/app_database.dart';
import 'player_controls_repository.dart';

/// Reusable non-secret control/engine snapshots. Applying a profile does not
/// modify the media library, current item's locator or device pairing settings.
class PlayerProfileRepository {
  const PlayerProfileRepository(this.database);
  final AppDatabase database;
  static const key = 'player.profiles.v1';
  Future<List<Map<String, dynamic>>> load() async {
    final value = await database.getSetting(key);
    return value == null
        ? []
        : (jsonDecode(value) as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
  }

  Future<String> save(String title, {String? id}) =>
      database.transaction(() async {
        if (title.trim().isEmpty || title.length > 200) {
          throw const FormatException(
            'Enter a profile name of 1–200 characters.',
          );
        }
        final profiles = await load();
        if (profiles.length >= 100 && id == null) {
          throw const FormatException('You can save up to 100 profiles.');
        }
        final repository = PlayerControlsRepository(database);
        final profile = <String, dynamic>{
          'id': id ?? const Uuid().v4(),
          'title': title.trim(),
          'controls': (await repository.load()).toJson(),
          'native': await repository.nativePreferences(),
          'speed': await database.getSetting('defaultPlaybackSpeed'),
        };
        final index = profiles.indexWhere((row) => row['id'] == profile['id']);
        if (index < 0) {
          profiles.add(profile);
        } else {
          profiles[index] = profile;
        }
        await database.setSetting(key, jsonEncode(profiles));
        return profile['id'] as String;
      });
  Future<void> apply(String id) => database.transaction(() async {
    final profile = (await load()).where((row) => row['id'] == id).firstOrNull;
    if (profile == null) throw StateError('This profile no longer exists.');
    await PlayerControlsRepository(
      database,
    ).save(PlayerControls.fromJson(profile['controls'] as Map));
    final native = Map<String, String>.from(profile['native'] as Map);
    // Imported native values are filtered against the bridge's supported schema
    // again before engine construction; credentials are never profile fields.
    await database.setSetting('player.native.preferences', jsonEncode(native));
    if (profile['speed'] is String) {
      await database.setSetting(
        'defaultPlaybackSpeed',
        profile['speed'] as String,
      );
    }
  });
  Future<void> delete(String id) => database.transaction(() async {
    final profiles = (await load())..removeWhere((row) => row['id'] == id);
    await database.setSetting(key, jsonEncode(profiles));
  });
}
