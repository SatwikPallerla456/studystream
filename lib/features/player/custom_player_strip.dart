import 'package:flutter/material.dart';
import '../../data/db/app_database.dart';
import '../../data/playback/playback_engine.dart';
import '../../domain/services/advanced_player_repository.dart';

/// Shared by library playback and live/network inputs. Transport is mandatory;
/// optional groups retain their saved order even in a narrow, wrapping layout.
class CustomPlayerStrip extends StatefulWidget {
  const CustomPlayerStrip({
    super.key,
    required this.player,
    required this.database,
    this.onTracks,
    this.onQueue,
    this.onPrevious,
    this.onNext,
    this.onRepeat,
    this.onShuffle,
    this.onCustomize,
    this.onTogglePlay,
    this.onSnapshot,
  });
  final Future<void> Function()? onSnapshot;
  final PlaybackEngine player;
  final AppDatabase database;
  final VoidCallback? onTracks,
      onQueue,
      onPrevious,
      onNext,
      onRepeat,
      onShuffle,
      onCustomize,
      onTogglePlay;
  @override
  State<CustomPlayerStrip> createState() => _CustomPlayerStripState();
}

class _CustomPlayerStripState extends State<CustomPlayerStrip> {
  List<String> _order = AdvancedPlayerRepository.defaultOrder;
  Map<String, String> _skin = {};
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = AdvancedPlayerRepository(widget.database);
    final order = await repo.order(), skin = await repo.skin();
    if (mounted)
      setState(() {
        _order = order;
        _skin = skin;
      });
  }

  Color color(String key, Color fallback) {
    final v = _skin[key]?.replaceFirst('#', '');
    return v == null ? fallback : Color(0xff000000 | int.parse(v, radix: 16));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'This control is unavailable for the current input.',
        );
    }
  }

  Widget button(String title, IconData icon, Future<void> Function()? action) =>
      IconButton(
        tooltip: title,
        icon: Icon(icon),
        onPressed: action == null ? null : () => _run(action),
      );
  String time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: widget.player.stream.position,
    initialData: widget.player.state.position,
    builder: (context, snapshot) {
      final p = widget.player, n = p is NativeVlcEngine ? p : null;
      final duration = p.state.duration.inMilliseconds.toDouble();
      final position = (snapshot.data ?? Duration.zero).inMilliseconds
          .toDouble()
          .clamp(0.0, duration > 0 ? duration : 1.0);
      final pieces = <String, Widget>{
        'Transport': StreamBuilder<bool>(
          stream: p.stream.playing,
          initialData: p.state.playing,
          builder: (c, s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onPrevious != null)
                IconButton(
                  tooltip: 'Previous',
                  onPressed: widget.onPrevious,
                  icon: const Icon(Icons.skip_previous),
                ),
              button(
                s.data == true ? 'Pause' : 'Play',
                s.data == true ? Icons.pause : Icons.play_arrow,
                widget.onTogglePlay == null
                    ? p.playOrPause
                    : () async {
                        widget.onTogglePlay!();
                      },
              ),
              if (widget.onNext != null)
                IconButton(
                  tooltip: 'Next',
                  onPressed: widget.onNext,
                  icon: const Icon(Icons.skip_next),
                ),
            ],
          ),
        ),
        'Timeline': SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: position,
                max: duration > 0 ? duration : 1,
                onChanged: duration > 0
                    ? (v) =>
                          _run(() => p.seek(Duration(milliseconds: v.round())))
                    : null,
              ),
              Text(
                '${time(p.state.position)} / ${time(p.state.duration)}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        'Volume': StreamBuilder<double>(
          stream: p.stream.volume,
          initialData: p.state.volume,
          builder: (c, s) => SizedBox(
            width: 150,
            child: Row(
              children: [
                button(
                  'Mute/unmute',
                  s.data == 0 ? Icons.volume_off : Icons.volume_up,
                  () => p.setVolume(s.data == 0 ? 100 : 0),
                ),
                Expanded(
                  child: Slider(
                    value: (s.data ?? 100).clamp(0, 100),
                    max: 100,
                    onChanged: (v) => _run(() => p.setVolume(v)),
                  ),
                ),
              ],
            ),
          ),
        ),
        'Tracks': IconButton(
          tooltip: 'Audio and subtitles',
          onPressed: widget.onTracks,
          icon: const Icon(Icons.subtitles_outlined),
        ),
        'Queue': IconButton(
          tooltip: 'Queue',
          onPressed: widget.onQueue,
          icon: const Icon(Icons.queue_music),
        ),
        'Skip': Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(
              'Back 10 seconds',
              Icons.replay_10,
              () => p.seek(p.state.position - const Duration(seconds: 10)),
            ),
            button(
              'Forward 10 seconds',
              Icons.forward_10,
              () => p.seek(p.state.position + const Duration(seconds: 10)),
            ),
          ],
        ),
        'Shuffle': IconButton(
          tooltip: 'Toggle shuffle',
          onPressed: widget.onShuffle,
          icon: const Icon(Icons.shuffle),
        ),
        'Repeat': IconButton(
          tooltip: 'Cycle repeat',
          onPressed: widget.onRepeat,
          icon: const Icon(Icons.repeat),
        ),
        if (n?.supports('outputs') == true)
          'Record': button(
            'Toggle recording',
            Icons.fiber_manual_record,
            n!.toggleRecording,
          ),
        if (n?.supports('snapshot') == true)
          'Snapshot': button('Snapshot', Icons.photo_camera, () async {
            if (widget.onSnapshot != null) {
              await widget.onSnapshot!();
            } else {
              await n!.snapshot();
            }
          }),
        if (n?.supports('mini') == true)
          'Mini-player': button(
            'Mini-player',
            Icons.picture_in_picture_alt,
            n!.toggleMini,
          ),
        if (n?.supports('fullscreen') == true)
          'Fullscreen': button(
            'Fullscreen',
            Icons.fullscreen,
            n!.toggleFullscreen,
          ),
      };
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: color('accent', const Color(0xffd37918)),
            onSurface: color('text', Colors.white),
          ),
          sliderTheme: SliderThemeData(
            inactiveTrackColor: color('track', const Color(0xff090909)),
            activeTrackColor: color('accent', const Color(0xffd37918)),
            thumbColor: color('accent', const Color(0xffd37918)),
          ),
          iconTheme: IconThemeData(color: color('text', Colors.white)),
          textTheme: Theme.of(
            context,
          ).textTheme.apply(bodyColor: color('text', Colors.white)),
        ),
        child: ColoredBox(
          color: color('chrome', const Color(0xff1b1b1b)),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final name in _order)
                        if (pieces[name] != null) pieces[name]!,
                      if (widget.onCustomize != null)
                        IconButton(
                          tooltip: 'Customize player',
                          onPressed: widget.onCustomize,
                          icon: const Icon(Icons.dashboard_customize_outlined),
                        ),
                    ],
                  ),
                  if (_error != null) Text(_error!),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
