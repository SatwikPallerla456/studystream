import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/catalog/online_catalog_provider.dart';
import '../../shared/widgets/app_top_bar.dart';

class MetadataProviderSettings extends StatefulWidget {
  const MetadataProviderSettings({super.key});
  @override
  State<MetadataProviderSettings> createState() =>
      _MetadataProviderSettingsState();
}

class _MetadataProviderSettingsState extends State<MetadataProviderSettings> {
  final _token = TextEditingController();
  bool _saved = false, _busy = true;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
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
    super.dispose();
  }

  Widget _link(String label, String url) => TextButton(
    onPressed: () async {
      if (!await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          ) &&
          mounted) {
        setState(
          () => _message = 'Could not open the provider website. Try again.',
        );
      }
    },
    child: Text(label),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(
      title: 'Metadata providers & credits',
      showBack: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Search sends only the title and optional year or episode numbers you enter to the selected provider. Your files, paths, notes and playback history are not sent. Nothing is matched automatically.',
        ),
        const SizedBox(height: 24),
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
            helperText:
                'Stored in the device keychain; excluded from backups and library sync.',
          ),
          onChanged: (_) => setState(() {}),
        ),
        Wrap(
          spacing: 12,
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
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_message!),
          ),
        const Divider(height: 32),
        for (final id in OnlineCatalogProvider.labels.keys) ...[
          Text(
            OnlineCatalogProvider.label(id),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(OnlineCatalogProvider.attribution(id)),
          _link('Provider information', switch (id) {
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
  );
}
