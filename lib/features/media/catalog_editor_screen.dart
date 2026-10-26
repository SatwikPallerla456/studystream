import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/catalog_identity_store.dart';
import '../../domain/catalog/catalog_provider.dart';
import '../../domain/catalog/online_catalog_provider.dart';
import '../../domain/catalog/catalog_online_policy.dart';
import '../settings/metadata_provider_settings.dart';
import 'catalog_candidate_artwork.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/item_artwork.dart' show catalogArtworkPathProvider;

/// Matching changes descriptive identity; editing changes sparse user fields.
/// Both keep the exact asset, study anchors and playback history intact.
class CatalogEditorScreen extends ConsumerStatefulWidget {
  const CatalogEditorScreen({super.key, required this.item});
  final Item item;
  @override
  ConsumerState<CatalogEditorScreen> createState() => _CatalogEditorState();
}

class _CatalogEditorState extends ConsumerState<CatalogEditorScreen> {
  static const _fields = {
    'title': 'Title',
    'year': 'Year',
    'synopsis': 'Synopsis',
    'credits': 'Credits',
    'genres': 'Genres',
    'show': 'TV show',
    'season': 'Season (0 for specials)',
    'episode': 'First episode',
    'episodeEnd': 'Last episode (for a shared file)',
    'artist': 'Artist',
    'album': 'Album',
    'author': 'Author',
    'series': 'Series',
    'volume': 'Volume',
    'chapter': 'Chapter / issue',
    'track': 'Track number',
    'disc': 'Disc number',
    'edition': 'Edition',
  };
  final _query = TextEditingController();
  final _year = TextEditingController();
  final _controllers = <String, TextEditingController>{};
  final _changes = <String, String>{};
  final _locks = <String, bool>{};
  LibraryKind _kind = LibraryKind.mixed;
  Set<String> get _primaryFields => {
    'title',
    'year',
    'synopsis',
    'credits',
    'genres',
    if (_kind == LibraryKind.television) ...[
      'show',
      'season',
      'episode',
      'episodeEnd',
    ],
    if (_kind == LibraryKind.music ||
        _kind == LibraryKind.musicVideos ||
        (_kind == LibraryKind.mixed && widget.item.itemType == 'audio')) ...[
      'artist',
      'album',
      'track',
      'disc',
    ],
    if ({
          LibraryKind.books,
          LibraryKind.comics,
          LibraryKind.audiobooks,
        }.contains(_kind) ||
        {'epub', 'cbz', 'pdf'}.contains(widget.item.itemType)) ...[
      'author',
      'series',
      'volume',
      'chapter',
      'edition',
    ],
    if (_kind == LibraryKind.podcasts) ...['artist', 'series'],
    if (_kind == LibraryKind.movies ||
        (_kind == LibraryKind.mixed && widget.item.itemType == 'video'))
      'edition',
  };
  JsonCatalogProvider? _provider;
  String _source = 'local-json';
  bool _searched = false;
  bool _hasCatalogArtwork = false;
  final _season = TextEditingController();
  final _episode = TextEditingController();
  final _episodeEnd = TextEditingController();
  CatalogProvider? get _activeProvider =>
      _source == 'local-json' ? _provider : OnlineCatalogProvider(_source);
  List<String> get _sources => [
    if ({LibraryKind.movies, LibraryKind.television}.contains(_kind)) ...[
      'tvdb',
      'tmdb',
    ],
    if (_kind == LibraryKind.television) 'tvmaze',
    if ({
      LibraryKind.books,
      LibraryKind.comics,
      LibraryKind.audiobooks,
    }.contains(_kind))
      'open-library',
    if (_kind == LibraryKind.music) 'musicbrainz',
    'local-json',
  ];
  List<Map<String, dynamic>> _candidates = [];
  Map<String, dynamic>? _decision;
  bool _loading = true, _busy = false;
  String? _error, _file;
  late CatalogIdentityStore _store;
  @override
  void initState() {
    super.initState();
    _store = CatalogIdentityStore(ref.read(appDatabaseProvider));
    _load();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final metadata = await MediaCatalogRepository(db).metadata(widget.item);
      _kind = await MediaCatalogRepository(
        db,
      ).libraryKind(widget.item.libraryId);
      if (metadata['category'] is String) {
        _kind = LibraryKind.values.firstWhere(
          (kind) => kind.name == metadata['category'],
          orElse: () => LibraryKind.mixed,
        );
      }
      _hasCatalogArtwork = metadata['artworkUrl'] is String;
      _source = _sources.first;
      _season.text = '${metadata['season'] ?? ''}';
      _episode.text = '${metadata['episode'] ?? ''}';
      _episodeEnd.text = '${metadata['episodeEnd'] ?? ''}';
      _decision = await _store.decision(widget.item.id);
      if (_sources.contains(_decision?['provider_id'])) {
        _source = _decision!['provider_id'] as String;
      }
      for (final field in _fields.keys) {
        _controllers[field] = TextEditingController(
          text: '${metadata[field] ?? ''}',
        );
      }
      final overrides = await db
          .customSelect(
            'SELECT field, locked FROM catalog_overrides WHERE item_id=?',
            variables: [Variable(widget.item.id)],
          )
          .get();
      for (final row in overrides) {
        _locks[row.data['field'] as String] = row.data['locked'] == 1;
      }
      _query.text =
          metadata['show'] as String? ??
          metadata['title'] as String? ??
          widget.item.title;
      _year.text = '${metadata['year'] ?? ''}';
    } catch (error) {
      _error = 'Details could not load. Reopen this title and try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : 'The request could not finish. Check your connection or provider setup and retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseCatalog() => _perform(() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open an offline metadata catalog',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final provider = await JsonCatalogProvider.fromFile(File(path));
    if (!mounted) return;
    _provider = provider;
    _source = 'local-json';
    _file = result!.files.single.name;
    await _search();
  });

  void _clearCandidates(String _) => setState(() {
    _candidates = [];
    _searched = false;
  });

  Future<void> _search() async {
    final year = _year.text.trim().isEmpty ? null : int.tryParse(_year.text);
    if (_year.text.trim().isNotEmpty &&
        (year == null || year < 0 || year > 9999)) {
      throw const FormatException('Enter a valid year or leave it empty.');
    }
    if (mounted)
      setState(() {
        _candidates = [];
        _searched = false;
      });
    final matches = await _activeProvider?.search(
      _query.text.trim(),
      year: year,
      type: _kind == LibraryKind.television
          ? 'episode'
          : _kind == LibraryKind.movies
          ? 'movie'
          : null,
    );
    if (mounted)
      setState(() {
        _candidates = matches ?? [];
        _searched = true;
      });
  }

  int? _episodeNumber(TextEditingController controller, String label) {
    if (controller.text.trim().isEmpty) return null;
    final number = int.tryParse(controller.text.trim());
    if (number == null || number < 0 || number > 100000) {
      throw FormatException('Enter a valid $label or leave it empty.');
    }
    return number;
  }

  Future<void> _select(Map<String, dynamic> hit) => _perform(() async {
    final provider = _activeProvider;
    if (provider == null) return;
    var candidate = hit;
    if (provider is OnlineCatalogProvider) {
      final season = _episodeNumber(_season, 'season');
      final episode = _episodeNumber(_episode, 'episode');
      final end = _episodeNumber(_episodeEnd, 'last episode');
      if ((season == null) != (episode == null)) {
        throw const FormatException(
          'Supply both season and episode, or leave both empty for show-level details.',
        );
      }
      if (end != null &&
          (episode == null || end < episode || end - episode >= 32)) {
        throw const FormatException(
          'A shared file needs an ordered range of at most 32 episodes.',
        );
      }
      candidate = await provider.details(
        hit,
        season: season,
        episode: episode,
        episodeEnd: end,
      );
    }
    if (!mounted) return;
    var useArtwork = candidate['artworkUrl'] != null;
    String? releaseId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            '${candidate['title']} (${candidate['year'] ?? 'year unknown'})',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (candidate['_releaseOptions'] case final List options) ...[
                    DropdownButtonFormField<String>(
                      initialValue: '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Album release & cover',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Recording only (no album cover)'),
                        ),
                        for (final option in options.whereType<Map>())
                          DropdownMenuItem(
                            value: option['id'] as String,
                            child: Text(
                              '${option['title']} · ${option['year'] ?? '?'} ${option['country'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => update(() {
                        releaseId = value == '' ? null : value;
                        final release = options
                            .whereType<Map>()
                            .where((r) => r['id'] == releaseId)
                            .firstOrNull;
                        candidate = OnlineCatalogProvider.chooseRelease(
                          candidate,
                          release == null
                              ? null
                              : Map<String, dynamic>.from(release),
                        );
                        useArtwork = candidate['artworkUrl'] != null;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (candidate['artworkUrl'] != null)
                    Center(
                      child: CatalogCandidateArtwork(
                        url: candidate['artworkUrl'] as String?,
                        width: 140,
                        height: 210,
                        allowRetry: true,
                      ),
                    ),
                  if (candidate['show'] != null)
                    Text(
                      '${candidate['show']} · ${candidate['season'] == null ? 'Show-level details' : 'S${candidate['season']} E${candidate['episode']}'}',
                    ),
                  if (candidate['artist'] != null)
                    Text(
                      '${candidate['artist']} · ${candidate['album'] ?? ''}',
                    ),
                  if (candidate['author'] != null)
                    Text('${candidate['author']}'),
                  const SizedBox(height: 12),
                  Text(
                    (candidate['synopsis'] as String? ?? '').isEmpty
                        ? 'No description supplied by this provider.'
                        : candidate['synopsis'] as String,
                  ),
                  if (candidate['_detailNote'] != null)
                    Text(candidate['_detailNote'] as String),
                  const SizedBox(height: 12),
                  Text(
                    'Provider: ${OnlineCatalogProvider.label(provider.id)} · ID: ${candidate['id']}',
                  ),
                  Text(
                    candidate['attribution'] as String? ??
                        'User-supplied catalog',
                  ),
                  if (CatalogOnlinePolicy.source(
                    candidate['sourceUrl'] as String?,
                  ))
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(candidate['sourceUrl'] as String),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('View original provider entry'),
                    ),
                  if (candidate['artworkUrl'] != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use provider artwork'),
                      subtitle: const Text(
                        'Missing covers fall back to local artwork.',
                      ),
                      value: useArtwork,
                      onChanged: (value) =>
                          update(() => useArtwork = value ?? false),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Locked edits are retained. Resume positions, notes and bookmarks stay with this file.',
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
              child: const Text('Use this match'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final selected = Map<String, dynamic>.from(candidate);
    if (!useArtwork) selected.remove('artworkUrl');
    await _store.select(
      widget.item,
      selected,
      providerId: provider.id,
      expectedRevision: _decision?['revision'] as int? ?? 0,
    );
    ref.invalidate(catalogArtworkPathProvider(widget.item));
    if (mounted) Navigator.pop(context);
  });

  Future<void> _saveFields() => _perform(() async {
    final db = ref.read(appDatabaseProvider);
    await db.transaction(() async {
      for (final entry in _changes.entries) {
        Object? value = entry.value == 'set'
            ? _controllers[entry.key]!.text.trim()
            : null;
        if ({
              'year',
              'season',
              'episode',
              'episodeEnd',
              'volume',
              'chapter',
              'track',
              'disc',
            }.contains(entry.key) &&
            entry.value == 'set') {
          final input = value as String;
          value = input.isEmpty
              ? null
              : entry.key == 'chapter'
              ? num.tryParse(input)
              : int.tryParse(input);
          if (value == null && input.isNotEmpty)
            throw FormatException('Enter a number for ${_fields[entry.key]}.');
        }
        await _store.override(
          widget.item,
          entry.key,
          value,
          remove: entry.value == 'remove',
          reset: entry.value == 'inherit',
          locked: _locks[entry.key] ?? true,
        );
      }
      final legacy = await MediaCatalogRepository(
        db,
      ).record('metadata:${widget.item.id}');
      await _store.resolve(widget.item, legacy?.data ?? {}, strictRanges: true);
    });
    ref.invalidate(catalogArtworkPathProvider(widget.item));
    if (mounted) Navigator.pop(context);
  });

  @override
  void dispose() {
    _query.dispose();
    _year.dispose();
    _season.dispose();
    _episode.dispose();
    _episodeEnd.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: 0,
    child: Scaffold(
      appBar: AppTopBar(
        title: 'Edit details',
        showBack: true,
        actions: [
          TextButton(
            onPressed: _loading || _busy || _changes.isEmpty
                ? null
                : _saveFields,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _controllers.length != _fields.length
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ??
                      'Details could not load. Go back and reopen this title.',
                ),
              ),
            )
          : Column(
              children: [
                if (_error != null)
                  MaterialBanner(
                    content: Text(_error!),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _error = null),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                if (_busy) const LinearProgressIndicator(),
                const TabBar(
                  tabs: [
                    Tab(text: 'Find match'),
                    Tab(text: 'Edit details'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            'Current match: ${_decision?['state'] ?? 'unmatched'}${_decision?['provider_id'] == null ? '' : ' · ${OnlineCatalogProvider.label(_decision!['provider_id'] as String)}'}',
                          ),
                          Text(widget.item.filename),
                          const SizedBox(height: 16),
                          const Text(
                            'Manual search: review candidates and choose the correct match. Automatic library identification keeps your selection and any cleared match.',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _source,
                            decoration: const InputDecoration(
                              labelText: 'Metadata provider',
                            ),
                            items: [
                              for (final source in _sources)
                                DropdownMenuItem(
                                  value: source,
                                  child: Text(
                                    source == 'local-json'
                                        ? 'Offline JSON catalog'
                                        : OnlineCatalogProvider.label(source),
                                  ),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (source) => setState(() {
                                    _source = source!;
                                    _candidates = [];
                                    _searched = false;
                                    _error = null;
                                  }),
                          ),
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const MetadataProviderSettings(),
                                    ),
                                  ),
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Provider setup & credits'),
                          ),
                          if (_source == 'local-json') ...[
                            const Text(
                              'Open a JSON array containing id, title and optional catalog fields.',
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _chooseCatalog,
                              icon: const Icon(Icons.file_open_outlined),
                              label: Text(_file ?? 'Open local JSON catalog'),
                            ),
                          ] else
                            Text(
                              'Search sends this title and optional year to ${OnlineCatalogProvider.label(_source)}. Files and private Study data stay on your device.',
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _query,
                            enabled: !_busy,
                            onChanged: _clearCandidates,
                            decoration: const InputDecoration(
                              labelText: 'Title (or ID for an offline catalog)',
                            ),
                            onSubmitted: (_) => _perform(_search),
                          ),
                          TextField(
                            controller: _year,
                            enabled: !_busy,
                            onChanged: _clearCandidates,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Year (optional)',
                            ),
                          ),
                          if (_kind == LibraryKind.television &&
                              _source != 'local-json') ...[
                            const SizedBox(height: 12),
                            const Text(
                              'For episode details, enter season and episode. Leave both empty for show-level details.',
                            ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final entry in [
                                  (_season, 'Season'),
                                  (_episode, 'Episode'),
                                  (_episodeEnd, 'Last episode (shared file)'),
                                ])
                                  SizedBox(
                                    width: 200,
                                    child: TextField(
                                      controller: entry.$1,
                                      enabled: !_busy,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: entry.$2,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _activeProvider == null || _busy
                                ? null
                                : () => _perform(_search),
                            child: const Text('Search for matches'),
                          ),
                          for (final candidate in _candidates)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              leading: CatalogCandidateArtwork(
                                url: candidate['artworkUrl'] as String?,
                                width: 48,
                                height: 64,
                              ),
                              title: Text(candidate['title'] as String),
                              subtitle: Text(
                                '${candidate['year'] ?? 'Unknown year'} · ${candidate['id']}\n${candidate['author'] ?? candidate['artist'] ?? candidate['show'] ?? ''} · ${candidate['_matchReason'] ?? ''}',
                              ),
                              trailing: const Icon(Icons.preview_outlined),
                              onTap: _busy ? null : () => _select(candidate),
                            ),
                          if (_searched && _candidates.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No candidates. Try a broader title or remove the year.',
                              ),
                            ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _perform(() async {
                                    await _store.clear(
                                      widget.item,
                                      expectedRevision:
                                          _decision?['revision'] as int? ?? 0,
                                    );
                                    if (mounted) Navigator.pop(context);
                                  }),
                            child: const Text(
                              'Clear match and return to local identification',
                            ),
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Edit this title. Only your changes are saved.',
                                ),
                              ),
                              Tooltip(
                                message:
                                    'Field options let you hide a field, reset it to catalog or filename data, or protect your edits during refresh.',
                                child: Icon(Icons.info_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Artwork source',
                            ),
                            hint: Text(
                              _hasCatalogArtwork
                                  ? 'Matched provider artwork'
                                  : 'Local artwork',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'inherit',
                                child: Text('Use matched provider artwork'),
                              ),
                              DropdownMenuItem(
                                value: 'remove',
                                child: Text('Use local artwork'),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => setState(() {
                                    if (value != null) {
                                      _changes['artworkUrl'] = value;
                                      _locks['artworkUrl'] = true;
                                    }
                                  }),
                          ),
                          for (final field in _fields.entries.where(
                            (field) => _primaryFields.contains(field.key),
                          ))
                            _fieldEditor(field),
                          ExpansionTile(
                            title: const Text('Advanced fields'),
                            subtitle: const Text(
                              'Fields used by other media categories',
                            ),
                            children: [
                              for (final field in _fields.entries.where(
                                (field) => !_primaryFields.contains(field.key),
                              ))
                                _fieldEditor(field),
                            ],
                          ),
                          FilledButton(
                            onPressed: _busy || _changes.isEmpty
                                ? null
                                : _saveFields,
                            child: const Text('Save changed fields'),
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

  Widget _fieldEditor(MapEntry<String, String> field) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: TextField(
      controller: _controllers[field.key],
      enabled: !_busy,
      maxLines: field.key == 'synopsis' ? 4 : 1,
      decoration: InputDecoration(
        labelText: field.value,
        helperText: switch (_changes[field.key]) {
          'remove' => 'Hidden when saved',
          'inherit' => 'Reset to catalog or filename when saved',
          'set' => 'Changed',
          _ => null,
        },
        suffixIcon: PopupMenuButton<String>(
          tooltip: 'Field options for ${field.value}',
          enabled: !_busy,
          onSelected: (action) => setState(() {
            if (action == 'lock') {
              _locks[field.key] = !(_locks[field.key] ?? true);
              _changes[field.key] = 'set';
            } else {
              _changes[field.key] = action;
            }
          }),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'remove', child: Text('Hide field')),
            const PopupMenuItem(
              value: 'inherit',
              child: Text('Reset to catalog / filename'),
            ),
            CheckedPopupMenuItem(
              value: 'lock',
              checked: _locks[field.key] ?? true,
              child: const Text('Keep my edits on refresh'),
            ),
          ],
          icon: const Icon(Icons.more_vert),
        ),
      ),
      onChanged: (_) => setState(() => _changes[field.key] = 'set'),
    ),
  );
}
