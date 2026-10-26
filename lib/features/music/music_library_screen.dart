import 'dart:convert';
import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:uuid/uuid.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/catalog/category_browse_repository.dart';
import '../../domain/music/music_models.dart';
import '../../domain/music/music_repository.dart';
import '../../domain/services/player_library_repository.dart';
import '../../shared/widgets/item_artwork.dart';
import '../library/category_browse_section.dart';
import 'music_provider.dart';

class MusicArtistScreen extends ConsumerStatefulWidget {
  const MusicArtistScreen({super.key, required this.artist, this.libraryId});
  final String artist;
  final String? libraryId;
  @override
  ConsumerState<MusicArtistScreen> createState() => _MusicArtistState();
}

class _MusicArtistState extends ConsumerState<MusicArtistScreen> {
  late final Future<List<Item>> _representative =
      MusicRepository(ref.read(appDatabaseProvider)).candidates(
        MusicRules(
          libraryId: widget.libraryId,
          artist: widget.artist,
          limit: 1,
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.artist),
      actions: [
        IconButton(
          tooltip: 'Smart playlists, history and outputs',
          icon: const Icon(Icons.library_music),
          onPressed: () => context.push('/music'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        FutureBuilder<List<Item>>(
          future: _representative,
          builder: (context, snapshot) {
            final item = snapshot.data?.firstOrNull;
            return Row(
              children: [
                if (item != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: ItemArtwork(item: item, size: 130),
                  ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.artist,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const Text(
                        'Albums, editions and recordings in your library',
                      ),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _play(),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play artist'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.push(
                              '/music?artist=${Uri.encodeComponent(widget.artist)}',
                            ),
                            child: const Text('Create artist radio'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        CategoryBrowseSection(
          kind: LibraryKind.music,
          libraryId: widget.libraryId,
          filters: {'artist': widget.artist},
          nested: true,
          group: 'album',
        ),
      ],
    ),
  );
  Future<void> _play() async {
    try {
      final ids = await CategoryBrowseRepository(ref.read(appDatabaseProvider))
          .queue(
            CategoryScope(
              kind: LibraryKind.music,
              libraryId: widget.libraryId,
              filters: {'artist': widget.artist},
            ),
          );
      if (ids.isEmpty) return;
      await ref.read(playerLibraryRepositoryProvider).setQueue(ids);
      if (mounted)
        context.push('/listen/${Uri.encodeComponent(ids.first)}?queue=1');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

Future<MusicRules?> editMusicRules(
  BuildContext context,
  AppDatabase db, {
  MusicRules initial = const MusicRules(),
  String title = 'Playlist rules',
}) async {
  final libraries =
      await (db.select(db.libraries)
            ..orderBy([(t) => d.OrderingTerm.asc(t.title)])
            ..limit(200))
          .get();
  if (!context.mounted) return null;
  var library = initial.libraryId,
      order = initial.order,
      favorite = initial.favorite,
      unplayed = initial.unplayed;
  final artist = TextEditingController(text: initial.artist),
      album = TextEditingController(text: initial.album),
      genre = TextEditingController(text: initial.genre),
      tag = TextEditingController(text: initial.tag),
      minYear = TextEditingController(text: '${initial.minYear}'),
      maxYear = TextEditingController(text: '${initial.maxYear}'),
      minDuration = TextEditingController(text: '${initial.minSeconds}'),
      maxDuration = TextEditingController(text: '${initial.maxSeconds}'),
      limit = TextEditingController(text: '${initial.limit}');
  String? error;
  final result = await showDialog<MusicRules>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: library ?? '',
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All music libraries'),
                    ),
                    for (final l in libraries)
                      DropdownMenuItem(value: l.id, child: Text(l.title)),
                  ],
                  onChanged: (v) => library = v == '' ? null : v,
                  decoration: const InputDecoration(labelText: 'Library'),
                ),
                for (final entry in {
                  artist: 'Artist (exact)',
                  album: 'Album (exact)',
                  genre: 'Genre contains',
                  tag: 'Organization tag (exact)',
                }.entries)
                  TextField(
                    controller: entry.key,
                    maxLength: 512,
                    decoration: InputDecoration(labelText: entry.value),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minYear,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'From year',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxYear,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Through year',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minDuration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Minimum seconds',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxDuration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Maximum seconds',
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  value: favorite,
                  onChanged: (v) => set(() => favorite = v),
                  title: const Text('Favorites only'),
                ),
                SwitchListTile(
                  value: unplayed,
                  onChanged: (v) => set(() => unplayed = v),
                  title: const Text('Never qualified as listened'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: order,
                  items: [
                    for (final v in [
                      'title',
                      'recent',
                      'leastPlayed',
                      'random',
                    ])
                      DropdownMenuItem(value: v, child: Text(v)),
                  ],
                  onChanged: (v) => order = v!,
                  decoration: const InputDecoration(labelText: 'Order'),
                ),
                TextField(
                  controller: limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Queue size (1–500)',
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final rules = MusicRules.fromJson({
                  'libraryId': library,
                  'artist': artist.text,
                  'album': album.text,
                  'genre': genre.text,
                  'tag': tag.text,
                  'favorite': favorite,
                  'unplayed': unplayed,
                  'minYear': int.tryParse(minYear.text) ?? -1,
                  'maxYear': int.tryParse(maxYear.text) ?? 10000,
                  'minSeconds': int.tryParse(minDuration.text) ?? -1,
                  'maxSeconds': int.tryParse(maxDuration.text) ?? -1,
                  'order': order,
                  'limit': int.tryParse(limit.text) ?? 0,
                });
                Navigator.pop(context, rules);
              } catch (e) {
                set(() => error = e.toString());
              }
            },
            child: const Text('Use rules'),
          ),
        ],
      ),
    ),
  );
  for (final controller in [
    artist,
    album,
    genre,
    tag,
    minYear,
    maxYear,
    minDuration,
    maxDuration,
    limit,
  ]) {
    controller.dispose();
  }
  return result;
}

class MusicLibraryScreen extends ConsumerStatefulWidget {
  const MusicLibraryScreen({super.key, this.initialTab = 0, this.artist});
  final int initialTab;
  final String? artist;
  @override
  ConsumerState<MusicLibraryScreen> createState() => _MusicLibraryState();
}

class _MusicLibraryState extends ConsumerState<MusicLibraryScreen> {
  MusicRepository get repo => MusicRepository(ref.read(appDatabaseProvider));
  final _historyPages = <String?>[];
  String? _historyAfter, _error;
  late Future<List<Map<String, dynamic>>> _smart = repo.settings(
    'music.smart:',
  );
  late Future<List<Map<String, dynamic>>> _history = repo.settings(
    'music.history:',
    limit: 65,
  );
  late Future<List<Map<String, dynamic>>> _outputs = repo.settings(
    'music.output:',
  );
  late MusicRules _radioRules = MusicRules(
    artist: widget.artist ?? '',
    order: 'random',
    limit: 50,
  );
  bool _busy = false, _cancel = false, _variety = true;
  int _avoidHours = 24, _processed = 0;
  MusicRules _bulkRules = const MusicRules();
  String _field = 'tags', _mode = 'add';
  final _value = TextEditingController();
  @override
  void initState() {
    super.initState();
    _restoreRadio();
  }

  Future<void> _restoreRadio() async {
    final raw = await ref
        .read(appDatabaseProvider)
        .getSetting('music.radio.config');
    if (raw != null && mounted) {
      try {
        final data = jsonDecode(raw) as Map;
        setState(() {
          _radioRules = widget.artist == null
              ? MusicRules.fromJson(data['rules'] as Map)
              : MusicRules(artist: widget.artist!, order: 'random', limit: 50);
          _variety = data['variety'] != false;
          _avoidHours = data['avoidHours'] as int? ?? 24;
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _cancel = true;
    _value.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _name(String title, String initial) async {
    var text = initial;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          maxLength: 200,
          onChanged: (v) => text = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => text.trim().isEmpty
                ? null
                : Navigator.pop(context, text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSmart([Map<String, dynamic>? row]) async {
    final name = await _name('Smart playlist', row?['title'] as String? ?? '');
    if (name == null || !mounted) return;
    final rules = await editMusicRules(
      context,
      ref.read(appDatabaseProvider),
      initial: row == null
          ? const MusicRules()
          : MusicRules.fromJson(row['rules'] as Map),
    );
    if (rules != null)
      await _run(() async {
        await repo.saveSmart(name, rules, id: row?['id'] as String?);
        if (mounted) setState(() => _smart = repo.settings('music.smart:'));
      });
  }

  Future<void> _playRules(
    MusicRules rules, {
    bool radio = false,
  }) => _run(() async {
    final tracks = radio
        ? await repo.radio(
            rules,
            count: rules.limit,
            variety: _variety,
            avoidHours: _avoidHours,
          )
        : await repo.candidates(rules);
    if (tracks.isEmpty)
      throw const FormatException(
        'No tracks match. Widen the rules or reduce the radio repeat window.',
      );
    if (radio) {
      final config = jsonEncode({
        'rules': rules.toJson(),
        'variety': _variety,
        'avoidHours': _avoidHours,
      });
      await ref
          .read(appDatabaseProvider)
          .setSetting('music.radio.config', config);
    }
    final queue = ref.read(playerLibraryRepositoryProvider);
    await ref.read(appDatabaseProvider).transaction(() async {
      await queue.setShuffle(false);
      await queue.setRepeat(QueueRepeat.off);
      await queue.setQueue(tracks.map((i) => i.id).toList());
    });
    if (mounted)
      await context.push(
        '/listen/${Uri.encodeComponent(tracks.first.id)}?queue=1${radio ? '&radio=1' : ''}',
      );
  });
  Future<void> _profile([Map<String, dynamic>? row]) async {
    await _run(() async {
      MediaKit.ensureInitialized();
      final active = ref.read(musicSessionProvider),
          temporary = active?.player == null ? Player() : null;
      final p = active?.player ?? temporary!;
      List<AudioDevice> devices;
      try {
        devices = p.state.audioDevices;
        if (devices.isEmpty)
          devices = await p.stream.audioDevices
              .firstWhere((v) => v.isNotEmpty)
              .timeout(
                const Duration(seconds: 4),
                onTimeout: () => [AudioDevice.auto()],
              );
      } finally {
        await temporary?.dispose();
      }
      if (!mounted) return;
      final profile = row == null
          ? AudioOutputProfile(
              id: const Uuid().v4(),
              name: 'New output profile',
            )
          : AudioOutputProfile.fromJson(row);
      final name = TextEditingController(text: profile.name);
      var device = profile.device,
          deviceLabel = profile.deviceLabel,
          normalization = profile.normalization,
          volume = profile.volume,
          preamp = profile.preamp,
          sampleRate = profile.sampleRate;
      final all = [
        const AudioDevice('auto', 'System default'),
        ...devices.where((d) => d.name != 'auto'),
      ];
      if (!all.any((d) => d.name == device)) {
        all.add(AudioDevice(device, '${profile.deviceLabel} (disconnected)'));
      }
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, set) => AlertDialog(
            title: const Text('Audio output profile'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: device,
                      items: [
                        for (final d in all)
                          DropdownMenuItem(
                            value: d.name,
                            child: Text(
                              d.description,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => set(() {
                        device = v!;
                        deviceLabel = all
                            .firstWhere((d) => d.name == device)
                            .description;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Output device',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: normalization,
                      items: [
                        for (final v in ['off', 'track', 'album', 'dynamic'])
                          DropdownMenuItem(value: v, child: Text(v)),
                      ],
                      onChanged: (v) => set(() => normalization = v!),
                      decoration: const InputDecoration(
                        labelText: 'Loudness normalization',
                      ),
                    ),
                    const Text(
                      'Track/album use embedded ReplayGain; untagged files keep their gain. Dynamic uses live loudness processing and requires the backend filter.',
                    ),
                    Text('Volume ${volume.round()}%'),
                    Slider(
                      value: volume,
                      max: 100,
                      onChanged: (v) => set(() => volume = v),
                    ),
                    Text('ReplayGain preamp ${preamp.toStringAsFixed(1)} dB'),
                    Slider(
                      value: preamp,
                      min: -12,
                      max: 12,
                      divisions: 48,
                      onChanged: (v) => set(() => preamp = v),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: sampleRate,
                      items: [
                        for (final rate in [44100, 48000, 88200, 96000, 192000])
                          DropdownMenuItem(
                            value: rate,
                            child: Text('$rate Hz'),
                          ),
                      ],
                      onChanged: (v) => set(() => sampleRate = v!),
                      decoration: const InputDecoration(
                        labelText: 'Shared output sample rate',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save profile'),
              ),
            ],
          ),
        ),
      );
      final title = name.text.trim();
      name.dispose();
      if (saved == true) {
        await repo.saveProfile(
          AudioOutputProfile(
            id: profile.id,
            name: title,
            device: device,
            deviceLabel: deviceLabel,
            volume: volume,
            preamp: preamp,
            normalization: normalization,
            sampleRate: sampleRate,
          ),
        );
        if (mounted) setState(() => _outputs = repo.settings('music.output:'));
      }
    });
  }

  Future<void> _bulk() async {
    final targets = await repo.prepareBulk(_bulkRules),
        job = targets.$1,
        count = targets.$2;
    if (!mounted || count == 0) {
      await repo.releaseBulk(job);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply to $count music recordings?'),
        content: Text(
          '$_mode $_field ${_value.text.isEmpty ? '' : '→ ${_value.text}'}\n\nThis changes catalog metadata. Original audio files remain unchanged. Cancellation retains completed edits.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply changes'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      await repo.releaseBulk(job);
      return;
    }
    await _run(() async {
      _cancel = false;
      _processed = 0;
      await repo.bulkTags(
        _bulkRules,
        field: _field,
        value: _value.text,
        mode: _mode,
        job: job,
        cancelled: () => _cancel || !mounted,
        progress: (n) {
          if (mounted && (n % 10 == 0 || n == count))
            setState(() => _processed = n);
        },
      );
      if (mounted)
        setState(
          () => _error =
              '${_cancel ? 'Stopped after' : 'Updated'} $_processed recordings.',
        );
    });
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    initialIndex: widget.initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Music listening'),
        actions: [
          TextButton(
            onPressed: () => context.push('/category/music'),
            child: const Text('Artists & albums'),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Smart playlists'),
            Tab(text: 'History'),
            Tab(text: 'Radio'),
            Tab(text: 'Outputs'),
            Tab(text: 'Library tags'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(_error!),
            ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Rules are evaluated against your library every time you play.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _editSmart(),
                      icon: const Icon(Icons.add),
                      label: const Text('New smart playlist'),
                    ),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _smart,
                      builder: (context, snapshot) => _rows(
                        snapshot,
                        (row) => ListTile(
                          title: Text(row['title'] as String),
                          subtitle: Text(
                            '${(row['rules'] as Map)['order']} · ${(row['rules'] as Map)['limit']} tracks',
                          ),
                          onTap: _busy
                              ? null
                              : () => _playRules(
                                  MusicRules.fromJson(row['rules'] as Map),
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit rules',
                                onPressed: () => _editSmart(row),
                                icon: const Icon(Icons.tune),
                              ),
                              IconButton(
                                tooltip: 'Delete smart playlist',
                                onPressed: () => _run(() async {
                                  await repo.deleteSetting(
                                    row['key'] as String,
                                  );
                                  if (mounted)
                                    setState(
                                      () => _smart = repo.settings(
                                        'music.smart:',
                                      ),
                                    );
                                }),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _history,
                  builder: (context, snapshot) {
                    final rows = snapshot.data ?? [];
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Actual listening time · last 5,000 sessions',
                              ),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await repo.clearHistory();
                                      if (mounted)
                                        setState(() {
                                          _historyAfter = null;
                                          _historyPages.clear();
                                          _history = repo.settings(
                                            'music.history:',
                                            limit: 65,
                                          );
                                        });
                                    }),
                              child: const Text('Clear history'),
                            ),
                          ],
                        ),
                        ...rows
                            .take(64)
                            .map(
                              (row) => ListTile(
                                title: Text('${row['title']}'),
                                subtitle: Text(
                                  '${row['artist']} · ${(row['listened'] as num).round()} s listened · ${DateTime.fromMillisecondsSinceEpoch(row['startedAt'] as int).toLocal()}${row['skipped'] == true ? ' · skipped' : ''}',
                                ),
                                onTap: () => context.push(
                                  '/listen/${Uri.encodeComponent(row['itemId'] as String)}',
                                ),
                              ),
                            ),
                        if (snapshot.hasError)
                          const Text(
                            'History could not load. Reopen this screen to retry.',
                          ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _historyPages.isEmpty
                                  ? null
                                  : () => setState(() {
                                      _historyAfter = _historyPages
                                          .removeLast();
                                      _history = repo.settings(
                                        'music.history:',
                                        before: _historyAfter,
                                        limit: 65,
                                      );
                                    }),
                              child: const Text('Previous'),
                            ),
                            TextButton(
                              onPressed: rows.length <= 64
                                  ? null
                                  : () => setState(() {
                                      _historyPages.add(_historyAfter);
                                      _historyAfter = rows[63]['key'] as String;
                                      _history = repo.settings(
                                        'music.history:',
                                        before: _historyAfter,
                                        limit: 65,
                                      );
                                    }),
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Build an evolving radio queue from a seed artist, album, genre or tag. The queue refills from matching local library recordings.',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seed: ${_radioRules.artist.isEmpty ? 'Any artist' : _radioRules.artist} · ${_radioRules.genre.isEmpty ? 'Any genre' : _radioRules.genre}',
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final rules = await editMusicRules(
                          context,
                          ref.read(appDatabaseProvider),
                          initial: _radioRules,
                          title: 'Radio seed & rules',
                        );
                        if (rules != null && mounted)
                          setState(() => _radioRules = rules);
                      },
                      child: const Text('Configure seed & queue size'),
                    ),
                    SwitchListTile(
                      value: _variety,
                      onChanged: (v) => setState(() => _variety = v),
                      title: const Text('Artist variety'),
                      subtitle: const Text(
                        'Avoid repeating the last three artists',
                      ),
                    ),
                    Text(
                      'Avoid recordings heard in the last $_avoidHours hours',
                    ),
                    Slider(
                      value: _avoidHours.toDouble().clamp(0, 168),
                      min: 0,
                      max: 168,
                      divisions: 28,
                      onChanged: (v) => setState(() => _avoidHours = v.round()),
                    ),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _playRules(_radioRules, radio: true),
                      icon: const Icon(Icons.radio),
                      label: const Text('Start radio'),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Profiles keep output device, loudness, volume and sample rate together. Device selection is local to this device.',
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _profile(),
                      icon: const Icon(Icons.add),
                      label: const Text('New output profile'),
                    ),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _outputs,
                      builder: (context, snapshot) => _rows(
                        snapshot,
                        (row) => ListTile(
                          title: Text('${row['name']}'),
                          subtitle: Text(
                            '${row['deviceLabel']} · ${row['normalization']} · ${row['sampleRate']} Hz',
                          ),
                          onTap: () => _run(() async {
                            final profile = AudioOutputProfile.fromJson(row),
                                session = ref.read(musicSessionProvider);
                            if (session != null)
                              await session.setProfile(profile);
                            else
                              await ref
                                  .read(appDatabaseProvider)
                                  .setSetting('music.activeOutput', profile.id);
                            if (mounted)
                              setState(
                                () => _error = '${profile.name} selected.',
                              );
                          }),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit profile',
                                onPressed: () => _profile(row),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete profile',
                                onPressed: () => _run(() async {
                                  await repo.deleteSetting(
                                    row['key'] as String,
                                  );
                                  if (mounted)
                                    setState(
                                      () => _outputs = repo.settings(
                                        'music.output:',
                                      ),
                                    );
                                }),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Apply catalog tag corrections across a named music library or a filtered scope. Unrelated metadata is retained.',
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final rules = await editMusicRules(
                                context,
                                ref.read(appDatabaseProvider),
                                initial: _bulkRules,
                                title: 'Choose music scope',
                              );
                              if (rules != null && mounted)
                                setState(() => _bulkRules = rules);
                            },
                      child: const Text('Choose library & filters'),
                    ),
                    FutureBuilder<int>(
                      future: repo.count(_bulkRules),
                      builder: (context, s) =>
                          Text('${s.data ?? '…'} matching music recordings'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _field,
                      items: [
                        for (final f in [
                          'tags',
                          'artist',
                          'album',
                          'albumArtist',
                          'composer',
                          'genres',
                          'year',
                          'credits',
                          'label',
                        ])
                          DropdownMenuItem(value: f, child: Text(f)),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _field = v!),
                      decoration: const InputDecoration(labelText: 'Field'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _mode,
                      items: [
                        for (final mode in [
                          'add',
                          'replace',
                          'remove',
                          'reset',
                        ])
                          DropdownMenuItem(value: mode, child: Text(mode)),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _mode = v!),
                      decoration: const InputDecoration(
                        labelText: 'Operation (add/remove only for tags)',
                      ),
                    ),
                    TextField(
                      controller: _value,
                      enabled: !_busy,
                      maxLength: 16000,
                      decoration: const InputDecoration(
                        labelText: 'Value (comma-separated organization tags)',
                      ),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _bulk,
                      child: const Text('Preview affected count & apply'),
                    ),
                    if (_busy)
                      TextButton(
                        onPressed: () => setState(() => _cancel = true),
                        child: Text(
                          'Cancel after current edit · $_processed completed',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _rows(
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
    Widget Function(Map<String, dynamic>) row,
  ) {
    if (snapshot.hasError)
      return const Text('Could not load. Reopen to retry.');
    if (!snapshot.hasData)
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    if (snapshot.data!.isEmpty)
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Nothing here yet.'),
      );
    return Column(children: snapshot.data!.map(row).toList());
  }
}
