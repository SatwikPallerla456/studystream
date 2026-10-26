import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/collection_browse_repository.dart';
import '../../domain/services/player_library_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../shared/widgets/item_artwork.dart';
import 'photo_slideshow_screen.dart';

class CollectionDetailsScreen extends ConsumerStatefulWidget {
  const CollectionDetailsScreen({
    super.key,
    required this.collectionId,
    this.onEdit,
  });
  final String collectionId;
  final Future<void> Function()? onEdit;
  @override
  ConsumerState<CollectionDetailsScreen> createState() =>
      _CollectionDetailsState();
}

class _CollectionDetailsState extends ConsumerState<CollectionDetailsScreen> {
  (int, String)? _after;
  final _history = <(int, String)?>[];
  bool _grid = false, _busy = false;
  String? _error;
  CollectionBrowseRepository get _repo =>
      CollectionBrowseRepository(ref.read(appDatabaseProvider));
  late Future<CollectionSummary?> _summary = _repo.summary(widget.collectionId);
  late Future<CollectionMembersPage> _page = _repo.page(widget.collectionId);
  void _refresh() => setState(() {
    _summary = _repo.summary(widget.collectionId);
    _page = _repo.page(widget.collectionId, after: _after);
  });
  Future<void> _play({String? start, bool shuffle = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ids = await _repo.queue(widget.collectionId);
      if (ids.isEmpty)
        throw const FormatException('No available audio or video members.');
      final index = start == null
          ? (shuffle ? Random().nextInt(ids.length) : 0)
          : ids.indexOf(start);
      if (index < 0)
        throw const FormatException(
          'This member is no longer available in the collection. Refresh and try again.',
        );
      final db = ref.read(appDatabaseProvider),
          player = PlayerLibraryRepository(ref.read(appDatabaseProvider));
      await db.transaction(() async {
        await player.setShuffle(false);
        await player.setQueue(ids, currentIndex: index);
        if (shuffle) await player.setShuffle(true);
      });
      if (mounted)
        await context.push(
          '/player/${Uri.encodeComponent(ids[index])}?queue=1',
        );
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : 'Playback could not start. Try again.',
        );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  Future<void> _read() async {
    final item = await _repo.readingStart(widget.collectionId);
    if (!mounted) return;
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No unfinished reading members. Choose a title below to read again.',
          ),
        ),
      );
      return;
    }
    await context.push(MediaVisuals.route(item));
    if (mounted) _refresh();
  }

  Future<void> _open(CollectionMember member) async {
    if (member.item.unavailable) return;
    if (member.item.itemType == 'image') {
      final summary = await _summary;
      if (!mounted || summary == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PhotoSlideshowScreen(
            libraryId: summary.record.libraryId,
            collectionId: widget.collectionId,
            initialItemId: member.item.id,
            albumTitle: summary.record.data['title'] as String,
          ),
        ),
      );
    } else if ({'audio', 'video'}.contains(member.item.itemType)) {
      await _play(start: member.item.id);
    } else {
      await context.push(MediaVisuals.route(member.item));
    }
    if (mounted) _refresh();
  }

  Future<void> _details(CollectionMember member) async {
    await context.push('/details/${Uri.encodeComponent(member.item.id)}');
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: 'Collection',
      showBack: true,
      actions: [
        if (widget.onEdit != null)
          IconButton(
            tooltip: 'Edit membership and order',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await widget.onEdit!();
              if (mounted) {
                _after = null;
                _history.clear();
                _refresh();
              }
            },
          ),
      ],
    ),
    body: FutureBuilder(
      future: _summary,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: TextButton(
              onPressed: _refresh,
              child: const Text('Could not load collection. Retry'),
            ),
          );
        if (!snapshot.hasData)
          return snapshot.connectionState == ConnectionState.done
              ? const Center(
                  child: Text('This collection is no longer available.'),
                )
              : const Center(child: CircularProgressIndicator());
        final summary = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              summary.record.data['title'] as String,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '${summary.libraryTitle} · ${summary.record.kind == 'album' ? 'Ordered album' : 'Collection'} · ${summary.total} members',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (summary.playable > 0)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _play(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play in order'),
                  ),
                if (summary.playable > 1)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _play(shuffle: true),
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Shuffle'),
                  ),
                if (summary.readable > 0)
                  OutlinedButton.icon(
                    onPressed: _read,
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Continue reading'),
                  ),
                if (summary.photos > 0)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PhotoSlideshowScreen(
                          libraryId: summary.record.libraryId,
                          collectionId: widget.collectionId,
                          albumTitle: summary.record.data['title'] as String,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.slideshow),
                    label: const Text('View photo album'),
                  ),
                IconButton(
                  tooltip: 'Grid view',
                  isSelected: _grid,
                  onPressed: () => setState(() => _grid = true),
                  icon: const Icon(Icons.grid_view),
                ),
                IconButton(
                  tooltip: 'List view',
                  isSelected: !_grid,
                  onPressed: () => setState(() => _grid = false),
                  icon: const Icon(Icons.view_list),
                ),
              ],
            ),
            const Text(
              'Members follow your saved order. Playback includes available audio/video; photos stay inside this album.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            const SizedBox(height: 16),
            FutureBuilder(
              future: _page,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return TextButton(
                    onPressed: _refresh,
                    child: const Text('Members could not load. Retry'),
                  );
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final page = snapshot.data!, members = snapshot.data!.members;
                return Column(
                  children: [
                    if (members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No members on this page. Edit membership or return to the first page.',
                        ),
                      ),
                    if (_grid)
                      LayoutBuilder(
                        builder: (context, box) {
                          final columns = (box.maxWidth / 180).floor().clamp(
                                1,
                                6,
                              ),
                              width =
                                  (box.maxWidth - (columns - 1) * 12) / columns;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final member in members)
                                SizedBox(
                                  width: width,
                                  height:
                                      width * 1.5 +
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(90),
                                  child: CinematicMediaCard(
                                    item: member.item,
                                    displayTitle: member.title,
                                    subtitle:
                                        '${member.position + 1} · ${member.item.unavailable ? 'Source offline' : MediaVisuals.action(member.item)}',
                                    progressPercent: member.progress,
                                    onOpen: () => _open(member),
                                    onDetails: () => _details(member),
                                  ),
                                ),
                            ],
                          );
                        },
                      )
                    else
                      for (final member in members)
                        ListTile(
                          leading: ItemArtwork(item: member.item, size: 56),
                          title: Text(
                            '${member.position + 1}. ${member.title}',
                          ),
                          subtitle: Text(
                            member.item.unavailable
                                ? 'Source offline · reconnect its library'
                                : '${member.completed ? 'Completed' : '${member.progress.round()}%'} · ${member.item.itemType.toUpperCase()}',
                          ),
                          onTap: () => _details(member),
                          trailing: IconButton(
                            tooltip: MediaVisuals.action(member.item),
                            icon: Icon(MediaVisuals.icon(member.item)),
                            onPressed: member.item.unavailable || _busy
                                ? null
                                : () => _open(member),
                          ),
                        ),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: _history.isEmpty
                              ? null
                              : () {
                                  _after = _history.removeLast();
                                  _refresh();
                                },
                          child: const Text('Previous page'),
                        ),
                        TextButton(
                          onPressed: !page.more
                              ? null
                              : () {
                                  _history.add(_after);
                                  _after = page.cursor;
                                  _refresh();
                                },
                          child: const Text('Next page'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    ),
  );
}
