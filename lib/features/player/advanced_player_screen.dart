import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/providers/app_providers.dart';
import '../../data/playback/playback_engine.dart';
import '../../domain/services/advanced_player_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/study_ui.dart';
import 'custom_player_strip.dart';
import 'native_output_tools.dart';

class AdvancedPlayerScreen extends ConsumerStatefulWidget {
  const AdvancedPlayerScreen({
    super.key,
    this.activePlayer,
    this.itemId,
    this.title,
    this.initialTab = 0,
  });
  final NativeVlcEngine? activePlayer;
  final String? itemId, title;
  final int initialTab;
  @override
  ConsumerState<AdvancedPlayerScreen> createState() => _AdvancedPlayerState();
}

class _AdvancedPlayerState extends ConsumerState<AdvancedPlayerScreen> {
  static const bridge = MethodChannel('tangerine/playback');
  late final AdvancedPlayerRepository repo = AdvancedPlayerRepository(
    ref.read(appDatabaseProvider),
  );
  final _url = TextEditingController(),
      _name = TextEditingController(),
      _path = TextEditingController();
  final _query = TextEditingController(),
      _language = TextEditingController(text: 'en');
  final _api = TextEditingController(), _token = TextEditingController();
  final _user = TextEditingController(),
      _password = TextEditingController(),
      _proxy = TextEditingController(),
      _proxyPassword = TextEditingController(),
      _proxyUser = TextEditingController();
  List<Map<String, dynamic>> _streams = [], _addons = [], _results = [];
  List<String> _order = AdvancedPlayerRepository.defaultOrder;
  Map<String, String> _skin = {};
  NativeVlcEngine? _live;
  StreamSubscription<String>? _errors;
  String? _message;
  bool _busy = false,
      _scrobble = false,
      _hasPassword = false,
      _hasProxyPassword = false,
      _ready = false;
  String _disc = 'dvdnav';
  int _page = 1, _pages = 1, _stripVersion = 0;
  String _searchedQuery = '', _searchedLanguage = '';
  @override
  void initState() {
    super.initState();
    _query.text = widget.title ?? '';
    _run(_load);
  }

  @override
  void dispose() {
    for (final c in [
      _url,
      _name,
      _path,
      _query,
      _language,
      _api,
      _token,
      _user,
      _password,
      _proxy,
      _proxyPassword,
      _proxyUser,
    ]) {
      c.dispose();
    }
    _errors?.cancel();
    _live?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _streams = await repo.list('streams');
    _addons = await repo.list('addons');
    _order = await repo.order();
    _skin = await repo.skin();
    try {
      final account = await OnlineSubtitleService().account();
      _api.text = account['key'] as String? ?? '';
      _token.text = account['token'] as String? ?? '';
    } catch (_) {
      _message =
          'Subtitle credentials could not be read from the OS credential store. Other player workflows remain available.';
    }
    if (Platform.isMacOS) {
      final data =
          await bridge.invokeMapMethod<String, dynamic>('services.status') ??
          {};
      _scrobble = data['scrobble'] == true;
      _hasPassword = data['hasLastfmPassword'] == true;
      _hasProxyPassword = data['hasProxyPassword'] == true;
      _user.text = data['lastfmUser'] as String? ?? '';
      _proxy.text = data['proxy'] as String? ?? '';
      _proxyUser.text = data['proxyUser'] as String? ?? '';
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted)
        setState(
          () => _message = e is FormatException
              ? e.message
              : e is PlatformException
              ? e.message ?? 'The native workflow could not finish.'
              : e is UnsupportedError
              ? e.message
              : 'The operation could not finish. Check permissions, connection and account setup, then retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File?> _file(List<String> extensions) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    final path = picked?.files.single.path;
    return path == null ? null : File(path);
  }

  Future<NativeVlcEngine> _player() async {
    if (_live != null) return _live!;
    await widget.activePlayer?.pause();
    final engine = await NativeVlcEngine.create();
    if (!mounted) {
      await engine.dispose();
      throw StateError('Closed');
    }
    _errors = engine.stream.error.listen((e) {
      if (mounted) setState(() => _message = e);
    });
    setState(() => _live = engine);
    return engine;
  }

  Future<void> _open(String raw) async {
    final uri = AdvancedPlayerRepository.openUri(raw);
    if (!Platform.isMacOS && !{'http', 'https'}.contains(uri.scheme))
      throw UnsupportedError(
        'RTSP/RTP/UDP/RTMP inputs currently require the macOS MyVLC bridge. HTTP and HTTPS streams work on other native platforms.',
      );
    final engine = await _player();
    await engine.open(Media(uri.toString()));
    await _runAddons(engine);
    if (mounted)
      setState(
        () => _message =
            'Stream opened. Live inputs may have no seekable duration.',
      );
  }

  Future<void> _runAddons(NativeVlcEngine player) async {
    if (!Platform.isMacOS) return;
    for (final addon in _addons.where((r) => r['enabled'] == true)) {
      try {
        await player.runAddon(addon['source'] as String, title: _name.text);
      } catch (_) {
        addon['enabled'] = false;
        await repo.saveList('addons', _addons);
        if (mounted)
          setState(
            () => _message =
                'A failing add-on was disabled. Review its source in Customize.',
          );
      }
    }
  }

  Future<void> _stop() async {
    final engine = _live;
    _live = null;
    await _errors?.cancel();
    await engine?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _importStreams() async {
    final file = await _file(['json']);
    if (file == null) return;
    final preview = await repo.previewStreams(file);
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Import saved streams?'),
        content: Text(
          '${preview.rows.length} supported network entries; ${preview.skipped} unsupported or credential-bearing entries skipped. Existing URLs are updated by identity. No connections are opened during import.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await repo.db.transaction(() async {
      for (final row in preview.rows) {
        await repo.saveStream(row['name'] as String, row['url'] as String);
      }
    });
    _streams = await repo.list('streams');
    if (mounted)
      setState(
        () => _message =
            'Saved network entries imported. Original MyVLC data is unchanged.',
      );
  }

  Future<void> _search(int page) async {
    final query = page == 1 ? _query.text : _searchedQuery,
        language = page == 1 ? _language.text : _searchedLanguage;
    final result = await OnlineSubtitleService().search(query, language, page);
    if (mounted)
      setState(() {
        _results = result.files;
        _pages = result.pages;
        _page = page;
        _searchedQuery = query;
        _searchedLanguage = language;
        _message = '${_results.length} subtitle files · page $_page of $_pages';
      });
  }

  Future<void> _download(Map<String, dynamic> result) async {
    if (widget.activePlayer == null || widget.itemId == null)
      throw const FormatException(
        'Open a library video, then choose Online subtitles from its player.',
      );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Download and attach subtitle?'),
        content: Text(
          '${result['name']}\nThis uses your OpenSubtitles download quota and attaches to ${widget.title ?? 'the current video'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Download & attach'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final path = await OnlineSubtitleService().download(
      (result['id'] as num).toInt(),
    );
    await widget.activePlayer!.setSubtitleTrack(SubtitleTrack.uri(path));
    await repo.db.setSetting('subtitle.${widget.itemId}', path);
    if (mounted)
      setState(
        () => _message =
            'Subtitle downloaded and attached. It will reopen with this title.',
      );
  }

  Widget _field(String label, TextEditingController c, {bool secret = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: c,
          obscureText: secret,
          enableSuggestions: !secret,
          autocorrect: false,
          decoration: InputDecoration(labelText: label),
        ),
      );
  Widget _button(
    String label,
    Future<void> Function() action, {
    IconData icon = Icons.arrow_forward,
  }) => OutlinedButton.icon(
    onPressed: _busy ? null : () => _run(action),
    icon: Icon(icon),
    label: Text(label),
  );
  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
  Widget _list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(20), children: children);
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    initialIndex: widget.initialTab,
    child: Scaffold(
      appBar: const AppTopBar(title: 'Advanced player', showBack: true),
      body: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Open inputs'),
              Tab(text: 'Online subtitles'),
              Tab(text: 'Accounts & proxy'),
              Tab(text: 'Customize'),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
          Expanded(
            child: !_ready
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Player workflows could not load yet.'),
                        _button('Retry loading', _load),
                      ],
                    ),
                  )
                : TabBarView(
                    children: [
                      _inputs(),
                      _subtitles(),
                      _accounts(),
                      _customize(),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
  Widget _inputs() => _list([
    _section('Network stream', [
      const Text(
        'Open HTTP/HTTPS streams on native players. macOS also supports RTSP, RTP, UDP and RTMP. Query/signed URLs are kept in the OS credential store when saved. Embedded username/password URLs are rejected.',
      ),
      _field('Stream URL', _url),
      _field('Saved stream name', _name),
      Wrap(
        spacing: 8,
        children: [
          _button('Open', () => _open(_url.text), icon: Icons.play_arrow),
          _button('Save stream', () async {
            await repo.saveStream(_name.text, _url.text);
            _streams = await repo.list('streams');
            if (mounted) setState(() => _message = 'Stream saved.');
          }, icon: Icons.bookmark_add_outlined),
          _button(
            'Import MyVLC network entries',
            _importStreams,
            icon: Icons.file_open,
          ),
        ],
      ),
      for (final row in _streams)
        ListTile(
          title: Text(row['name'] as String),
          subtitle: Text(
            row['url'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: _busy
              ? null
              : () {
                  _run(() async {
                    _url.text = await repo.streamAddress(row);
                    _name.text = row['name'] as String;
                  });
                },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Play saved stream',
                onPressed: _busy
                    ? null
                    : () => _run(
                        () async => _open(await repo.streamAddress(row)),
                      ),
                icon: const Icon(Icons.play_arrow),
              ),
              IconButton(
                tooltip: 'Remove saved stream',
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await repo.removeStream(row);
                        _streams = await repo.list('streams');
                        if (mounted) setState(() {});
                      }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
    ]),
    _section('Capture', [
      Text(
        Platform.isMacOS
            ? 'Choose devices and start preview explicitly. Recordings use a save dialog. Screen recording needs macOS permission; it may require an app restart.'
            : 'Camera, microphone and screen capture currently require macOS. This target has no capture adapter.',
      ),
      if (Platform.isMacOS)
        Wrap(
          spacing: 8,
          children: [
            _button('Camera / microphone…', () async {
              await bridge.invokeMethod<void>('capture.show');
            }, icon: Icons.videocam_outlined),
            _button('Start screen capture', () async {
              final engine = await _player();
              await engine.openInput('screen');
            }, icon: Icons.screen_share_outlined),
          ],
        ),
    ]),
    _section('Disc', [
      Text(
        Platform.isMacOS
            ? 'Open a readable disc folder, image or device using installed VLC modules. Protected discs require compatible drive and decoding support.'
            : 'Disc inputs and DVD navigation currently require macOS.',
      ),
      if (Platform.isMacOS) ...[
        DropdownButtonFormField<String>(
          initialValue: _disc,
          decoration: const InputDecoration(labelText: 'Disc type'),
          items: [
            for (final e in const {
              'dvdnav': 'DVD with menus',
              'dvd': 'DVD without menus',
              'bluray': 'Blu-ray',
              'cdda': 'Audio CD',
              'vcd': 'Video CD',
            }.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: _busy ? null : (v) => setState(() => _disc = v!),
        ),
        _field('Disc folder/image/device path', _path),
        Wrap(
          spacing: 8,
          children: [
            _button('Choose folder', () async {
              final p = await FilePicker.platform.getDirectoryPath();
              if (p != null) _path.text = p;
            }, icon: Icons.folder_open),
            _button('Choose image', () async {
              final f = await _file(['iso', 'img']);
              if (f != null) _path.text = f.path;
            }, icon: Icons.album),
            _button('Open disc', () async {
              final engine = await _player();
              await engine.openInput(_disc, path: _path.text);
            }, icon: Icons.play_arrow),
          ],
        ),
      ],
    ]),
    if (_live != null)
      _section('Input player', [
        SizedBox(height: 300, child: _live!.videoSurface()),
        CustomPlayerStrip(
          key: ValueKey('live$_stripVersion'),
          player: _live!,
          database: repo.db,
          onTracks: () => _liveTracks(),
        ),
        Wrap(
          spacing: 8,
          children: [
            _button('Stop input', _stop, icon: Icons.stop),
            if (_live!.supports('outputs'))
              _button('Record / output…', () async {
                await showStudyAdaptiveModal<void>(
                  context: context,
                  builder: (_) => NativeOutputTools(engine: _live!),
                );
              }, icon: Icons.fiber_manual_record),
          ],
        ),
        if (Platform.isMacOS)
          StreamBuilder<Duration>(
            stream: _live!.stream.position,
            builder: (c, s) {
              final count = (_live!.diagnostics['discTitles'] as num? ?? 0)
                  .toInt();
              final chapters = (_live!.diagnostics['chapters'] as num? ?? 0)
                  .toInt();
              return Column(
                children: [
                  Wrap(
                    children: [
                      for (final action in [
                        'menu',
                        'up',
                        'left',
                        'activate',
                        'right',
                        'down',
                      ])
                        _button(
                          action == 'menu' ? 'DVD menu' : action,
                          () => _live!.discNavigate(action),
                        ),
                    ],
                  ),
                  if (count > 0)
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Disc title',
                      ),
                      items: [
                        for (var i = 0; i < count.clamp(0, 256); i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text('Title ${i + 1}'),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) _run(() => _live!.discTitle(v));
                      },
                    ),
                  if (chapters > 0)
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Chapter'),
                      items: [
                        for (var i = 0; i < chapters.clamp(0, 512); i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text('Chapter ${i + 1}'),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) _run(() => _live!.setChapter(v));
                      },
                    ),
                ],
              );
            },
          ),
      ]),
  ]);
  void _liveTracks() {
    showDialog<void>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Input tracks'),
        children: [
          for (final track in _live!.state.tracks.audio)
            SimpleDialogOption(
              child: Text(track.title ?? 'Audio ${track.id}'),
              onPressed: () {
                Navigator.pop(c);
                _run(() => _live!.setAudioTrack(track));
              },
            ),
          for (final track in _live!.state.tracks.subtitle)
            SimpleDialogOption(
              child: Text(track.title ?? 'Subtitle ${track.id}'),
              onPressed: () {
                Navigator.pop(c);
                _run(() => _live!.setSubtitleTrack(track));
              },
            ),
        ],
      ),
    );
  }

  Widget _subtitles() => _list([
    _section('OpenSubtitles', [
      const Text(
        'Your query is sent only when you press Search. Use an OpenSubtitles API key and an account bearer token for downloads. Credentials are stored in the OS credential store.',
      ),
      _field('API key', _api, secret: true),
      _field('Bearer token', _token, secret: true),
      Wrap(
        spacing: 8,
        children: [
          _button('Save credentials', () async {
            if (_api.text.trim().isEmpty)
              throw const FormatException('Enter an API key.');
            await OnlineSubtitleService.credentials.write(
              jsonEncode({
                'key': _api.text.trim(),
                'token': _token.text.trim(),
              }),
            );
            if (mounted)
              setState(() => _message = 'Subtitle credentials saved securely.');
          }, icon: Icons.lock_outline),
          _button('Disconnect', () async {
            await OnlineSubtitleService.credentials.clear();
            _api.clear();
            _token.clear();
            if (mounted)
              setState(() => _message = 'Saved subtitle credentials removed.');
          }, icon: Icons.link_off),
        ],
      ),
      if (widget.activePlayer == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Search is available here. To download and attach, open Online subtitles from the library video player.',
          ),
        ),
      _field('Title / episode', _query),
      _field('Language code', _language),
      _button('Search', () => _search(1), icon: Icons.search),
      for (final row in _results)
        ListTile(
          title: Text(row['name'].toString()),
          subtitle: Text(
            '${row['language']} · ${row['downloads']} downloads${row['hearing'] == true ? ' · hearing impaired' : ''}',
          ),
          trailing: _button(
            'Download & attach',
            () => _download(row),
            icon: Icons.download,
          ),
        ),
      Wrap(
        spacing: 8,
        children: [
          if (_page > 1) _button('Previous page', () => _search(_page - 1)),
          if (_page < _pages) _button('Next page', () => _search(_page + 1)),
        ],
      ),
    ]),
  ]);
  Widget _accounts() => _list([
    if (!Platform.isMacOS)
      const Text(
        'Last.fm scrobbling and authenticated playback proxy configuration currently use the macOS MyVLC adapter. Other platforms do not yet expose these service modules.',
      ),
    if (Platform.isMacOS) ...[
      _section('Last.fm scrobbling', [
        const Text(
          'Opt in to send music listening history to Last.fm through libVLC’s audioscrobbler. Changes apply to players opened after saving. Audio must contain artist/title metadata; Last.fm and the installed VLC module determine acceptance.',
        ),
        SwitchListTile(
          title: const Text('Enable scrobbling'),
          value: _scrobble,
          onChanged: _busy ? null : (v) => setState(() => _scrobble = v),
        ),
        _field('Last.fm username', _user),
        _field(
          _hasPassword
              ? 'Password (saved; leave blank to keep)'
              : 'Last.fm password',
          _password,
          secret: true,
        ),
      ]),
      _section('Playback HTTP proxy', [
        const Text(
          'Use http://host:port without embedded credentials. The proxy applies to new macOS libVLC players, not metadata/subtitle services or companion pairing. Leave the address empty to disable it.',
        ),
        _field('HTTP proxy address', _proxy),
        _field('Proxy username (optional)', _proxyUser),
        _field(
          _hasProxyPassword
              ? 'Proxy password (saved; leave blank to keep)'
              : 'Proxy password',
          _proxyPassword,
          secret: true,
        ),
        Wrap(
          spacing: 8,
          children: [
            _button('Save accounts & proxy', () async {
              await bridge.invokeMethod<void>('services.save', {
                'scrobble': _scrobble,
                'lastfmUser': _user.text.trim(),
                'lastfmPassword': _password.text,
                'proxy': _proxy.text.trim(),
                'proxyUser': _proxyUser.text.trim(),
                'proxyPassword': _proxyPassword.text,
              });
              _password.clear();
              _proxyPassword.clear();
              await _load();
              if (mounted)
                setState(
                  () => _message =
                      'Settings saved. Open a new player to apply them.',
                );
            }, icon: Icons.lock_outline),
            _button('Disconnect & clear secrets', () async {
              await bridge.invokeMethod<void>('services.save', {
                'scrobble': false,
                'lastfmUser': '',
                'proxy': '',
                'clearlastfmPassword': true,
                'clearproxyPassword': true,
              });
              _password.clear();
              _proxyPassword.clear();
              await _load();
              if (mounted)
                setState(
                  () => _message =
                      'Accounts disconnected and saved secrets removed.',
                );
            }, icon: Icons.link_off),
          ],
        ),
      ]),
    ],
  ]);
  Widget _customize() => _list([
    _section('Player control strip', [
      const Text(
        'Choose groups and move them up or down. Transport remains available. Save to apply when returning to playback.',
      ),
      for (var i = 0; i < _order.length; i++)
        ListTile(
          title: Text(_order[i]),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Move up',
                onPressed: _busy || i == 0
                    ? null
                    : () {
                        setState(() {
                          final entry = _order.removeAt(i);
                          _order.insert(i - 1, entry);
                        });
                      },
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: _busy || i == _order.length - 1
                    ? null
                    : () {
                        setState(() {
                          final entry = _order.removeAt(i);
                          _order.insert(i + 1, entry);
                        });
                      },
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: 'Remove group',
                onPressed: _busy || _order[i] == 'Transport'
                    ? null
                    : () => setState(() => _order.removeAt(i)),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        ),
      Wrap(
        spacing: 8,
        children: [
          for (final group in AdvancedPlayerRepository.groups.where(
            (v) => !_order.contains(v),
          ))
            ActionChip(
              label: Text('Add $group'),
              onPressed: _busy ? null : () => setState(() => _order.add(group)),
            ),
        ],
      ),
      Wrap(
        spacing: 8,
        children: [
          _button('Save control strip', () async {
            await repo.saveOrder(_order);
            if (mounted)
              setState(() {
                _stripVersion++;
                _message = 'Player controls saved.';
              });
          }, icon: Icons.save_outlined),
          _button('Reset controls', () async {
            _order = List.of(AdvancedPlayerRepository.defaultOrder);
            await repo.saveOrder(_order);
            if (mounted) setState(() => _stripVersion++);
          }, icon: Icons.restart_alt),
        ],
      ),
    ]),
    _section('MyVLC JSON skin', [
      const Text(
        'Import the original six-digit hex color format. This customizes player chrome; library category styling stays consistent. VLC .vlt skins are unsupported.',
      ),
      Text(
        _skin.isEmpty
            ? 'Using Tangerine colors'
            : 'Custom colors: ${_skin.keys.join(', ')}',
      ),
      Wrap(
        spacing: 8,
        children: [
          _button('Import skin JSON', () async {
            final file = await _file(['json']);
            if (file == null) return;
            await repo.importSkin(file);
            _skin = await repo.skin();
            if (mounted) setState(() => _stripVersion++);
          }, icon: Icons.palette_outlined),
          _button('Reset skin', () async {
            await repo.db.setSetting('player.advanced.skin', '{}');
            _skin = {};
            if (mounted) setState(() => _stripVersion++);
          }, icon: Icons.restart_alt),
        ],
      ),
    ]),
    _section('JavaScript add-ons', [
      Text(
        Platform.isMacOS
            ? 'MyVLC JavaScript only; VLC Lua extensions are unsupported. Imported scripts start disabled. Enabled scripts run at playback start with player.title, position, play, pause, stop, seek(seconds), setVolume(percent), and optional onPlay(title). Runs are limited to 2 seconds and 64 commands, without filesystem/shell/network access.'
            : 'JavaScript add-on execution currently requires macOS. You can import/manage scripts here; they will not execute on this platform.',
      ),
      _button('Import JavaScript (disabled)', () async {
        final file = await _file(['js']);
        if (file == null) return;
        await repo.importAddon(file);
        _addons = await repo.list('addons');
        if (mounted)
          setState(
            () => _message =
                'Imported disabled. Review the script before enabling it.',
          );
      }, icon: Icons.extension_outlined),
      for (final addon in _addons)
        ListTile(
          title: Text(addon['name'] as String),
          subtitle: Text(
            addon['enabled'] == true
                ? 'Enabled for new playback sessions'
                : 'Disabled',
          ),
          leading: Switch(
            value: addon['enabled'] == true,
            onChanged: _busy || !Platform.isMacOS
                ? null
                : (v) => _run(() async {
                    addon['enabled'] = v;
                    await repo.saveList('addons', _addons);
                    if (mounted) setState(() {});
                  }),
          ),
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: 'Review source',
                icon: const Icon(Icons.code),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(addon['name'] as String),
                    content: SizedBox(
                      width: 680,
                      child: SingleChildScrollView(
                        child: SelectableText(addon['source'] as String),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Run once on active player',
                icon: const Icon(Icons.play_arrow),
                onPressed:
                    _busy ||
                        !Platform.isMacOS ||
                        widget.activePlayer == null && _live == null
                    ? null
                    : () => _run(() async {
                        await (widget.activePlayer ?? _live)!.runAddon(
                          addon['source'] as String,
                        );
                        if (mounted)
                          setState(() => _message = 'Add-on completed.');
                      }),
              ),
              IconButton(
                tooltip: 'Remove add-on',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        _addons.remove(addon);
                        await repo.saveList('addons', _addons);
                        if (mounted) setState(() {});
                      }),
              ),
            ],
          ),
        ),
    ]),
  ]);
}
