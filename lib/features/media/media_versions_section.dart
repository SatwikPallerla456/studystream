import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/catalog_playback.dart';
import '../../shared/widgets/cinematic_media.dart';
import 'title_files_screen.dart';

class MediaVersionsSection extends ConsumerStatefulWidget {
  const MediaVersionsSection({super.key, required this.item, this.onChanged});
  final Item item;
  final VoidCallback? onChanged;
  @override
  ConsumerState<MediaVersionsSection> createState() => _VersionsState();
}

class _VersionsState extends ConsumerState<MediaVersionsSection> {
  CatalogPlayback get _playback =>
      CatalogPlayback(ref.read(appDatabaseProvider));
  late Future<TitleFiles> _files = _playback.files(widget.item);
  late Future<List<({Item item, String edition, String representation})>>
  _versions = _playback.versions(widget.item);
  late Future<Item?> _next = _playback.nextEpisode(widget.item);
  @override
  void didUpdateWidget(covariant MediaVersionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) _refresh();
  }

  void _refresh() => setState(() {
    _files = _playback.files(widget.item);
    _versions = _playback.versions(widget.item);
    _next = _playback.nextEpisode(widget.item);
  });
  Future<void> _resume() async {
    try {
      final target = await _playback.resumePart(widget.item.id);
      if (mounted)
        context.push(
          CatalogPlayback.partRoute(
            widget.item.id,
            target.itemId,
            position: target.position,
          ),
        );
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check that every part is available and save the title timing again.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Editions and files',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TitleFilesScreen(item: widget.item),
                  ),
                );
                if (mounted) {
                  _refresh();
                  widget.onChanged?.call();
                }
              },
              icon: const Icon(Icons.tune),
              label: const Text('Manage title files'),
            ),
          ],
        ),
      ),
      FutureBuilder<List<({Item item, String edition, String representation})>>(
        future: _versions,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text('Versions could not load.');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          return Column(
            children: [
              for (final version in snapshot.data!)
                Card(
                  child: ListTile(
                    leading: Icon(MediaVisuals.icon(version.item)),
                    title: Text(
                      [
                        version.edition,
                        if (version.representation.isNotEmpty)
                          version.representation,
                      ].join(' · '),
                    ),
                    subtitle: Text(
                      '${version.item.filename}${version.item.unavailable ? ' · unavailable' : ''}',
                    ),
                    selected: version.item.id == widget.item.id,
                    trailing: IconButton(
                      tooltip:
                          'Open this exact file with its own resume position',
                      onPressed: version.item.unavailable
                          ? null
                          : () =>
                                context.push(MediaVisuals.route(version.item)),
                      icon: const Icon(Icons.play_circle_outline),
                    ),
                    onTap: () => context.push(
                      '/details/${Uri.encodeComponent(version.item.id)}',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      FutureBuilder<TitleFiles>(
        future: _files,
        builder: (context, snapshot) {
          final files = snapshot.data;
          if (files == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (files.parts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${files.parts.length} ordered parts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    FilledButton.icon(
                      onPressed: _resume,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume multipart title'),
                    ),
                  ],
                ),
                for (var index = 0; index < files.parts.length; index++)
                  ListTile(
                    leading: Text('${index + 1}'),
                    title: Text(
                      files.parts[index].item.userTitle ??
                          files.parts[index].item.title,
                    ),
                    subtitle: Text(files.parts[index].item.filename),
                    trailing: const Icon(Icons.play_circle_outline),
                    enabled: !files.parts[index].item.unavailable,
                    onTap: () => context.push(
                      CatalogPlayback.partRoute(
                        widget.item.id,
                        files.parts[index].item.id,
                      ),
                    ),
                  ),
              ],
              if (files.extras.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Extras', style: Theme.of(context).textTheme.titleLarge),
                for (final extra in files.extras)
                  ListTile(
                    leading: Icon(MediaVisuals.icon(extra.item)),
                    title: Text(extra.item.userTitle ?? extra.item.title),
                    subtitle: Text(
                      CatalogPlayback.extraKinds[extra.kind] ?? 'Extra',
                    ),
                    enabled: !extra.item.unavailable,
                    onTap: () => context.push(MediaVisuals.route(extra.item)),
                  ),
              ],
            ],
          );
        },
      ),
      FutureBuilder<Item?>(
        future: _next,
        builder: (context, snapshot) => snapshot.data == null
            ? const SizedBox.shrink()
            : OutlinedButton.icon(
                onPressed: () => context.push(
                  '/details/${Uri.encodeComponent(snapshot.data!.id)}',
                ),
                icon: const Icon(Icons.skip_next),
                label: const Text('Next numbered episode'),
              ),
      ),
    ],
  );
}
