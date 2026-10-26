import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../data/db/app_database.dart';
import 'player_controls_repository.dart';
import 'player_library_repository.dart';

/// Reusable non-secret control/engine snapshots. Applying a profile does not
/// modify the media library, current item's locator or device pairing settings.
class PlayerProfileRepository {
  const PlayerProfileRepository(this.database, {this.queueNamespace});
  final String? queueNamespace;
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
          'effects': jsonDecode(
            await database.getSetting('player.profile.effects') ?? 'null',
          ),
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
    final controls = PlayerControlsRepository(database);
    if (profile['controls'] is Map) {
      await controls.save(PlayerControls.fromJson(profile['controls'] as Map));
    } else if (profile['controlsPatch'] is Map) {
      await controls.save(
        PlayerControls.fromJson({
          ...(await controls.load()).toJson(),
          ...Map<String, dynamic>.from(profile['controlsPatch'] as Map),
        }),
      );
    }
    final native = Map<String, String>.from(profile['native'] as Map);
    final queue = PlayerLibraryRepository(
      database,
      queueNamespace: queueNamespace,
    );
    final queueState = await queue.load();
    if (native['repeat'] != null && native['repeat'] != queueState.repeat.name)
      await queue.setRepeat(
        QueueRepeat.values.firstWhere(
          (v) => v.name == native['repeat'],
          orElse: () => QueueRepeat.off,
        ),
      );
    if (native['shuffle'] != null &&
        (native['shuffle'] == 'true') != queueState.shuffle)
      await queue.setShuffle(native['shuffle'] == 'true');
    // Imported native values are filtered against the bridge's supported schema
    // again before engine construction; credentials are never profile fields.
    await database.setSetting('player.native.preferences', jsonEncode(native));
    if (profile['effects'] is Map)
      await database.setSetting(
        'player.profile.effects',
        jsonEncode(profile['effects']),
      );
    else
      await database.setSetting('player.profile.effects', 'null');
    if (profile['speed'] is String) {
      await database.setSetting(
        'defaultPlaybackSpeed',
        profile['speed'] as String,
      );
    }
  });
  Future<void> importLegacy(List<Map<String, dynamic>> incoming) =>
      database.transaction(() async {
        final profiles = await load();
        final removed =
            (jsonDecode(
                      await database.getSetting(
                            'player.profiles.removedLegacy',
                          ) ??
                          '[]',
                    )
                    as List)
                .cast<String>();
        for (final profile in incoming) {
          if (removed.contains(profile['id']) ||
              profiles.any((p) => p['id'] == profile['id']))
            continue;
          if (profiles.length >= 100)
            throw const FormatException(
              'At most 100 player profiles can be stored.',
            );
          profiles.add(profile);
        }
        await database.setSetting(key, jsonEncode(profiles));
      });
  Future<void> delete(String id) => database.transaction(() async {
    if (id.startsWith('legacy:')) {
      final removed =
          (jsonDecode(
                    await database.getSetting(
                          'player.profiles.removedLegacy',
                        ) ??
                        '[]',
                  )
                  as List)
              .cast<String>();
      if (!removed.contains(id)) removed.add(id);
      await database.setSetting(
        'player.profiles.removedLegacy',
        jsonEncode(removed),
      );
    }
    final profiles = (await load())..removeWhere((row) => row['id'] == id);
    await database.setSetting(key, jsonEncode(profiles));
  });
}
