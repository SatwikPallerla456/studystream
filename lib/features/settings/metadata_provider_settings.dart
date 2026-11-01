import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/catalog/online_catalog_provider.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/tangerine_controls.dart';

class MetadataProviderSettings extends StatefulWidget {
  const MetadataProviderSettings({super.key});
  @override
  State<MetadataProviderSettings> createState() =>
      _MetadataProviderSettingsState();
}

class _MetadataProviderSettingsState extends State<MetadataProviderSettings> {
  final _token = TextEditingController();
  final _tvdb = TextEditingController();
  bool _tvdbSaved = false;

  Future<void> _saveTvdb({bool remove = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await CatalogCredentials.saveTvdb(remove ? '' : _tvdb.text);
      if (mounted)
        setState(() {
          _tvdbSaved = !remove;
          _tvdb.clear();
          _message = remove
              ? 'TheTVDB key removed from this device.'
              : 'TheTVDB project key saved securely. Return to Find match to search.';
        });
    } catch (error) {
      if (mounted)
        setState(
          () => _message = error is FormatException
              ? error.message.toString()
              : 'Could not save the key. Check access to the device keychain.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _saved = false, _busy = true;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tvdb = await CatalogCredentials.readTvdb();
      if (mounted) setState(() => _tvdbSaved = tvdb?.isNotEmpty == true);
      final saved = await CatalogCredentials.read();
      if (mounted) setState(() => _saved = saved?.isNotEmpty == true);
    } catch (_) {
      if (mounted)
        setState(
          () => _message =
              'Secure storage is unavailable. Unlock the device keychain and reopen this screen.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool remove = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await CatalogCredentials.save(remove ? '' : _token.text);
      if (mounted)
        setState(() {
          _saved = !remove && _token.text.trim().isNotEmpty;
          _token.clear();
          _message = remove
              ? 'TMDB token removed from this device.'
              : 'TMDB token saved securely. Return to Find match to search.';
        });
    } catch (error) {
      if (mounted)
        setState(
          () => _message = error is FormatException
              ? error.message.toString()
              : 'The token could not be saved. Check access to the device keychain.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _token.dispose();
    _tvdb.dispose();
    super.dispose();
  }

  Widget _link(String label, String url) => Align(
    alignment: Alignment.centerLeft,
    child: TangerineInteraction(
      child: TextButton.icon(
        icon: const Icon(Icons.open_in_new, size: 18),
        onPressed: () async {
          if (!await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ) &&
              mounted) {
            setState(
              () =>
                  _message = 'Could not open the provider website. Try again.',
            );
          }
        },
        label: Text(label),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(
      title: 'Metadata providers & credits',
      showBack: true,
    ),
    bottomNavigationBar: _message == null
        ? null
        : SafeArea(
            top: false,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_message!),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss message',
                      onPressed: () => setState(() => _message = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Metadata for your library',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Manual search and automatic movie/TV identification send only titles, years and episode information to the provider. Control automatic identification in each library’s Identify titles or Processing screen. Files, paths, notes and playback history are not sent.',
            ),
            const SizedBox(height: 20),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'TheTVDB · movies and TV',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              CatalogCredentials.hasBundledTvdbKey
                  ? 'Included with Tangerine · no setup required'
                  : _tvdbSaved
                  ? 'Project key saved on this device'
                  : 'Add the Tangerine project API key',
            ),
            const Text(
              'Default provider for new movie and TV matches. Episode matching uses official aired order.',
            ),
            const SizedBox(height: 12),
            if (!CatalogCredentials.hasBundledTvdbKey) ...[
              TextField(
                controller: _tvdb,
                obscureText: true,
                enabled: !_busy,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: _tvdbSaved
                      ? 'Replacement TheTVDB project API key'
                      : 'TheTVDB project API key',
                  helperMaxLines: 3,
                  helperText:
                      'Stored in the device keychain; excluded from backups and library sync.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy || _tvdb.text.trim().isEmpty
                        ? null
                        : () => _saveTvdb(),
                    child: const Text('Save TheTVDB key'),
                  ),
                  if (_tvdbSaved)
                    TextButton(
                      onPressed: _busy ? null : () => _saveTvdb(remove: true),
                      child: const Text('Remove TheTVDB key'),
                    ),
                  _link(
                    'TheTVDB project dashboard',
                    'https://thetvdb.com/dashboard',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            Text(
              'Optional providers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'TMDB · movies and TV',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              _saved
                  ? 'Token saved on this device'
                  : 'Requires your own API Read Access Token',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              obscureText: true,
              enabled: !_busy,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: _saved
                    ? 'Replacement read-access token'
                    : 'API Read Access Token',
                helperMaxLines: 3,
                helperText:
                    'Stored in the device keychain; excluded from backups and library sync.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy || _token.text.trim().isEmpty
                      ? null
                      : () => _save(),
                  child: const Text('Save token'),
                ),
                if (_saved)
                  TextButton(
                    onPressed: _busy ? null : () => _save(remove: true),
                    child: const Text('Remove token'),
                  ),
                _link(
                  'Get a TMDB token',
                  'https://www.themoviedb.org/settings/api',
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Provider credits',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            for (final id in OnlineCatalogProvider.labels.keys) ...[
              if (id == 'tmdb')
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SvgPicture.asset(
                      'assets/brand/tmdb.svg',
                      width: 120,
                      semanticsLabel: 'The Movie Database (TMDB)',
                    ),
                  ),
                ),
              Text(
                OnlineCatalogProvider.label(id),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(OnlineCatalogProvider.attribution(id)),
              _link('Provider information', switch (id) {
                'tvdb' => 'https://thetvdb.com',
                'tmdb' => 'https://www.themoviedb.org',
                'tvmaze' => 'https://www.tvmaze.com/api',
                'open-library' => 'https://openlibrary.org/developers/api',
                _ => 'https://musicbrainz.org/doc/MusicBrainz_API',
              }),
              const SizedBox(height: 12),
            ],
            const Text(
              'TVmaze, Open Library and MusicBrainz need no API key. Results and covers depend on provider coverage. MusicBrainz may have no description or cover for a recording. Personal videos, photos, courses and other unsupported categories retain manual details and offline catalogs.',
            ),
            _link('Cover Art Archive', 'https://coverartarchive.org'),
          ],
        ),
      ),
    ),
  );
}
