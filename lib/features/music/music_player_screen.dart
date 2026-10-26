import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/music/music_session.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/music/music_models.dart';
import '../../domain/music/music_repository.dart';
import '../../domain/services/player_library_repository.dart';
import '../../shared/widgets/item_artwork.dart';
import '../../shared/widgets/lesson_tools_sheet.dart';
import 'music_art.dart';
import 'music_provider.dart';
import 'music_library_screen.dart';

String musicTime(Duration d) =>
    '${d.inHours > 0 ? '${d.inHours}:' : ''}${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({
    super.key,
    required this.itemId,
    this.fromQueue = false,
    this.radio = false,
  });
  final String itemId;
  final bool fromQueue, radio;
  @override
  ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends ConsumerState<MusicPlayerScreen>
    with WidgetsBindingObserver {
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      _run(() async {
        await ref
            .read(musicSessionProvider.notifier)
            .start(
              widget.itemId,
              fromQueue: widget.fromQueue,
              radio: widget.radio,
            );
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      final session = ref.read(musicSessionProvider);
      unawaited(
        session?.player?.state.playing == false
            ? session?.pause()
            : Future<void>.value(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _edit(MusicSession session) async {
    final track = session.track;
    if (track == null) return;
    final lyric = TextEditingController(
      text:
          track.extras['lrc'] as String? ??
          track.extras['lyrics'] as String? ??
          '',
    );
    var timed = track.extras['lrc'] != null;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Lyrics'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: timed,
                  onChanged: (v) => set(() => timed = v),
                  title: const Text('Synchronized LRC timestamps'),
                ),
                TextField(
                  controller: lyric,
                  maxLines: 12,
                  maxLength: 65536,
                  decoration: InputDecoration(
                    hintText: timed
                        ? '[00:12.50] A line of lyrics'
                        : 'Paste lyrics you are allowed to use',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final text = lyric.text;
    lyric.dispose();
    if (accepted == true)
      await _run(() async {
        await MusicRepository(ref.read(appDatabaseProvider)).saveExtras(
          track.item,
          {timed ? 'lrc' : 'lyrics': text},
          reset: {timed ? 'lyrics' : 'lrc'},
        );
        await session.refreshExtras();
      });
  }

  Future<void> _import(MusicSession session) async {
    final track = session.track;
    if (track == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lrc', 'txt', 'cue'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    await _run(() async {
      final file = File(path);
      if (await file.length() > 65536)
        throw const FormatException('Sidecars are limited to 64 KiB');
      final text = (await file.readAsString()).replaceFirst('\ufeff', '');
      final changes = path.toLowerCase().endsWith('.cue')
          ? {
              'cue': jsonEncode(
                CueTrack.parse(
                  text,
                  track.item.filename,
                ).map((t) => t.toJson()).toList(),
              ),
            }
          : path.toLowerCase().endsWith('.lrc')
          ? {'lrc': text}
          : {'lyrics': text};
      if (changes['cue'] is String &&
          session.player!.state.duration > Duration.zero &&
          CueTrack.decode(changes['cue']!).any(
            (c) => c.startMs >= session.player!.state.duration.inMilliseconds,
          ))
        throw const FormatException('Cue times extend beyond this recording');
      await MusicRepository(ref.read(appDatabaseProvider)).saveExtras(
        track.item,
        changes,
        reset: changes.containsKey('lyrics')
            ? {'lrc'}
            : changes.containsKey('lrc')
            ? {'lyrics'}
            : {},
      );
      await session.refreshExtras();
    });
  }

  Future<void> _preferences(MusicSession session) async {
    var gapless = session.gapless,
        fade = session.crossfade,
        intensity = session.visualIntensity,
        style = session.visualStyle;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Listening & atmosphere'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Gapless transitions'),
                  subtitle: const Text(
                    'Keep the audio output open between queued tracks',
                  ),
                  value: gapless,
                  onChanged: (v) => set(() => gapless = v),
                ),
                Text(
                  'Crossfade: ${fade.toStringAsFixed(1)} s · 0 keeps album transitions intact',
                ),
                Slider(
                  value: fade,
                  min: 0,
                  max: 12,
                  divisions: 24,
                  onChanged: (v) => set(() => fade = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: style,
                  items: [
                    for (final value in ['auto', 'calm', 'punchy', 'off'])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (v) => set(() => style = v!),
                  decoration: const InputDecoration(
                    labelText: 'Artwork response',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Motion intensity ${(intensity * 100).round()}%'),
                Slider(
                  value: intensity,
                  onChanged: (v) => set(() => intensity = v),
                ),
                const Text(
                  'Colours come from the artwork. Audio energy drives the pulse. Reduced motion keeps the background still.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true)
      await _run(
        () => session.preferences(
          seamless: gapless != session.gapless ? gapless : null,
          fade: fade != session.crossfade ? fade : null,
          intensity: intensity,
          style: style,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(musicSessionProvider);
    if (session == null)
      return Scaffold(
        appBar: AppBar(title: const Text('Now playing')),
        body: Center(child: Text(_error ?? 'Preparing music…')),
      );
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final track = session.track, p = session.player;
        if (track == null || p == null)
          return Scaffold(
            appBar: AppBar(title: const Text('Now playing')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? session.error ?? 'Preparing music…'),
                  TextButton(
                    onPressed: () => _run(
                      () => ref
                          .read(musicSessionProvider.notifier)
                          .start(
                            widget.itemId,
                            fromQueue: widget.fromQueue,
                            radio: widget.radio,
                          ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        final reduced =
            MediaQuery.disableAnimationsOf(context) ||
            session.visualStyle == 'off';
        final position = p.state.position, duration = p.state.duration;
        var active = -1;
        for (var i = 0; i < session.lyrics.length; i++) {
          if (session.lyrics[i].milliseconds <= position.inMilliseconds)
            active = i;
          else
            break;
        }
        return Theme(
          data: ThemeData.dark(useMaterial3: true),
          child: Scaffold(
            backgroundColor: const Color(0xff11151c),
            appBar: AppBar(
              backgroundColor: const Color(0xff11151c),
              title: const Text('Now playing'),
              actions: [
                IconButton(
                  tooltip: 'Queue & playlists',
                  icon: const Icon(Icons.queue_music),
                  onPressed: () => context.push(
                    '/playlists?current=${Uri.encodeComponent(track.item.id)}',
                  ),
                ),
                IconButton(
                  tooltip: 'Music library',
                  icon: const Icon(Icons.library_music),
                  onPressed: () => context.push('/music'),
                ),
                IconButton(
                  tooltip: 'Listening & atmosphere',
                  icon: const Icon(Icons.tune),
                  onPressed: () => _preferences(session),
                ),
                IconButton(
                  tooltip: 'Outputs',
                  icon: const Icon(Icons.speaker_group_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MusicLibraryScreen(initialTab: 3),
                    ),
                  ),
                ),
              ],
            ),
            body: MusicAtmosphere(
              session: session,
              child: Focus(
                autofocus: true,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent ||
                      FocusManager.instance.primaryFocus?.context?.widget
                          is EditableText)
                    return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.space) {
                    _run(
                      p.state.playing
                          ? session.pause
                          : ref.read(musicSessionProvider.notifier).resume,
                    );
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _run(
                      () =>
                          session.seek(position - const Duration(seconds: 10)),
                    );
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    _run(
                      () =>
                          session.seek(position + const Duration(seconds: 10)),
                    );
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth > 850;
                    final artwork = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label:
                              'Album artwork; audio-reactive colour background',
                          image: true,
                          child: Transform.scale(
                            scale: reduced
                                ? 1
                                : 1 +
                                      session.beat *
                                          session.visualIntensity *
                                          .018 +
                                      session.energy *
                                          session.visualIntensity *
                                          .012,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: ItemArtwork(
                                item: track.item,
                                size: wide
                                    ? 310
                                    : box.maxWidth.clamp(180, 330) - 48,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          track.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MusicArtistScreen(
                                artist: track.artist,
                                libraryId: track.item.libraryId,
                              ),
                            ),
                          ),
                          child: Text(
                            track.artist,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        Text(
                          '${track.metadata['album'] ?? ''}${track.metadata['edition'] == null ? '' : ' · ${track.metadata['edition']}'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    );
                    final timeline = Column(
                      children: [
                        Slider(
                          value: position.inMilliseconds.toDouble().clamp(
                            0,
                            duration.inMilliseconds > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1,
                          ),
                          max: duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1,
                          onChanged: duration > Duration.zero
                              ? (v) => _run(
                                  () => session.seek(
                                    Duration(milliseconds: v.round()),
                                  ),
                                )
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(musicTime(position)),
                              Text(musicTime(duration)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (session.queued)
                              IconButton(
                                tooltip: 'Shuffle queue',
                                isSelected: session.shuffled,
                                icon: const Icon(Icons.shuffle),
                                onPressed: () => _run(
                                  () => ref
                                      .read(playerLibraryRepositoryProvider)
                                      .setShuffle(!session.shuffled),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Previous recording',
                              icon: const Icon(Icons.skip_previous),
                              onPressed: () => _run(() => session.skip(-1)),
                            ),
                            IconButton.filled(
                              iconSize: 42,
                              tooltip: p.state.playing ? 'Pause' : 'Play',
                              icon: Icon(
                                p.state.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              onPressed: () => _run(
                                p.state.playing
                                    ? session.pause
                                    : ref
                                          .read(musicSessionProvider.notifier)
                                          .resume,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next recording',
                              icon: const Icon(Icons.skip_next),
                              onPressed: () => _run(() => session.skip(1)),
                            ),
                            if (session.queued)
                              IconButton(
                                tooltip: session.repeatOne
                                    ? 'Repeat one'
                                    : session.repeatAll
                                    ? 'Repeat queue'
                                    : 'Repeat off',
                                isSelected:
                                    session.repeatOne || session.repeatAll,
                                icon: Icon(
                                  session.repeatOne
                                      ? Icons.repeat_one
                                      : Icons.repeat,
                                ),
                                onPressed: () => _run(
                                  () => ref
                                      .read(playerLibraryRepositoryProvider)
                                      .setRepeat(
                                        session.repeatOne
                                            ? QueueRepeat.all
                                            : session.repeatAll
                                            ? QueueRepeat.off
                                            : QueueRepeat.one,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.volume_down, size: 18),
                            Expanded(
                              child: Slider(
                                value: session.volume,
                                max: 100,
                                onChanged: (v) =>
                                    _run(() => session.setVolume(v)),
                              ),
                            ),
                            Text('${session.volume.round()}%'),
                          ],
                        ),
                        Text(
                          '${session.profile.name} · ${session.profile.normalization} normalization · ${session.crossfade > 0
                              ? '${session.crossfade}s crossfade'
                              : session.gapless
                              ? 'gapless'
                              : 'standard'}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        if (session.meterMessage != null)
                          Text(
                            session.meterMessage!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        if ((_error ?? session.error) case final String message)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              message,
                              style: const TextStyle(color: Colors.amberAccent),
                            ),
                          ),
                      ],
                    );
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 10,
                          children: [
                            TextButton.icon(
                              onPressed: () => _edit(session),
                              icon: const Icon(Icons.lyrics_outlined),
                              label: const Text('Edit lyrics'),
                            ),
                            TextButton.icon(
                              onPressed: () => _import(session),
                              icon: const Icon(Icons.file_open_outlined),
                              label: const Text('Import lyrics / CUE'),
                            ),
                            TextButton.icon(
                              onPressed: () => showLessonToolsSheet(
                                context: context,
                                database: ref.read(appDatabaseProvider),
                                item: track.item,
                                title: 'Listening notes & bookmarks',
                                currentPositionSeconds:
                                    position.inMilliseconds / 1000,
                                onJumpToPosition: (s) => _run(
                                  () => session.seek(
                                    Duration(milliseconds: (s * 1000).round()),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.bookmark_outline),
                              label: const Text('Notes & bookmarks'),
                            ),
                          ],
                        ),
                        if (session.lyrics.isNotEmpty) ...[
                          const Text(
                            'SYNCHRONIZED LYRICS',
                            style: TextStyle(
                              letterSpacing: 2,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (
                            var i = (active - 2).clamp(
                              0,
                              session.lyrics.length,
                            );
                            i < (active + 5).clamp(0, session.lyrics.length);
                            i++
                          )
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: TextButton(
                                onPressed: () => _run(
                                  () => session.seek(
                                    Duration(
                                      milliseconds:
                                          session.lyrics[i].milliseconds,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  session.lyrics[i].text.isEmpty
                                      ? '♪'
                                      : session.lyrics[i].text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: i == active ? 25 : 18,
                                    fontWeight: i == active
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: i == active
                                        ? Colors.white
                                        : Colors.white38,
                                  ),
                                ),
                              ),
                            ),
                        ] else
                          SelectableText(
                            track.extras['lyrics'] as String? ??
                                'Add lyrics or import an LRC file to follow along.',
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.8,
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (session.cues.isNotEmpty ||
                            session.chapters.isNotEmpty)
                          ExpansionTile(
                            title: Text(
                              session.cues.isNotEmpty
                                  ? 'Recording tracks'
                                  : 'Chapters',
                            ),
                            initiallyExpanded: true,
                            children: [
                              for (final cue in session.cues)
                                ListTile(
                                  dense: true,
                                  selected:
                                      position.inMilliseconds >= cue.startMs &&
                                      (cue.endMs == null ||
                                          position.inMilliseconds < cue.endMs!),
                                  leading: Text('${cue.number}'),
                                  title: Text(cue.title),
                                  subtitle: Text(cue.artist),
                                  trailing: Text(
                                    musicTime(
                                      Duration(milliseconds: cue.startMs),
                                    ),
                                  ),
                                  onTap: () => _run(
                                    () => session.seek(
                                      Duration(milliseconds: cue.startMs),
                                    ),
                                  ),
                                ),
                              if (session.cues.isEmpty)
                                for (final row in session.chapters)
                                  ListTile(
                                    title: Text(row['title'] as String),
                                    onTap: () => _run(
                                      () => session.seek(
                                        Duration(
                                          milliseconds:
                                              ((row['seconds'] as num) * 1000)
                                                  .round(),
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        TextButton.icon(
                          onPressed: () => context.push(
                            '/player/${Uri.encodeComponent(track.item.id)}?native=1',
                          ),
                          icon: const Icon(Icons.settings_input_component),
                          label: const Text(
                            'Open with full native player controls',
                          ),
                        ),
                        ExpansionTile(
                          title: const Text('Credits & recording'),
                          children: [
                            for (final key in [
                              'artist',
                              'albumArtist',
                              'composer',
                              'lyricist',
                              'credits',
                              'label',
                              'year',
                              'edition',
                            ])
                              if (track.metadata[key] != null)
                                ListTile(
                                  dense: true,
                                  title: Text(key),
                                  subtitle: SelectableText(
                                    '${track.metadata[key]}',
                                  ),
                                ),
                            ListTile(
                              title: const Text('File'),
                              subtitle: Text(track.item.filename),
                            ),
                            const ListTile(
                              title: Text('Audio engine'),
                              subtitle: Text(
                                'Continuous music · media_kit / mpv',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          artwork,
                                          const SizedBox(height: 24),
                                          timeline,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 60),
                                    Expanded(
                                      child: Card(
                                        color: Colors.black38,
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: details,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    artwork,
                                    timeline,
                                    const SizedBox(height: 26),
                                    Card(
                                      color: Colors.black38,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: details,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MusicDock extends ConsumerWidget {
  const MusicDock({super.key, required this.onOpen});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(musicSessionProvider);
    if (session == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final track = session.track;
        if (track == null) return const SizedBox.shrink();
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ItemArtwork(item: track.item, size: 44),
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(track.artist, maxLines: 1),
              onTap: onOpen,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: session.player?.state.playing == true
                        ? 'Pause'
                        : 'Play',
                    onPressed: () => unawaited(
                      (session.player?.state.playing == true
                              ? session.pause()
                              : ref
                                    .read(musicSessionProvider.notifier)
                                    .resume())
                          .catchError((Object _) {}),
                    ),
                    icon: Icon(
                      session.player?.state.playing == true
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Stop music',
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        ref.read(musicSessionProvider.notifier).stop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
