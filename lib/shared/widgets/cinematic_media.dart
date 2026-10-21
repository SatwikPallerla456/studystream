import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import 'item_artwork.dart';
import 'remote_item_artwork.dart';

abstract final class MediaVisuals {
  static const posterRatio = 2 / 3;
  static const backdropRatio = 16 / 9;
  static const artworkDecodeWidth = 960;
  static bool isListening(Item item) => item.itemType == 'audio';
  static bool isReading(Item item) =>
      !['audio', 'video', 'image'].contains(item.itemType);
  static IconData icon(Item item) => isListening(item)
      ? Icons.headphones_rounded
      : isReading(item)
      ? Icons.menu_book_rounded
      : item.itemType == 'image'
      ? Icons.photo_outlined
      : Icons.movie_outlined;
  static String action(Item item) => isReading(item)
      ? 'Read'
      : item.itemType == 'image'
      ? 'View'
      : 'Play';
  static String route(Item item) => switch (item.itemType) {
    'video' || 'audio' => '/player/${Uri.encodeComponent(item.id)}',
    'epub' || 'cbz' => '/book/${Uri.encodeComponent(item.id)}',
    'pdf' => '/pdf/${Uri.encodeComponent(item.id)}',
    _ => '/resource/${Uri.encodeComponent(item.id)}',
  };
}

/// Sizes decoding to the card; missing artwork remains an honest local tile.
class CinematicArtwork extends ConsumerWidget {
  const CinematicArtwork({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
  });
  final Item item;
  final BoxFit fit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path =
        ref.watch(catalogArtworkPathProvider(item)).asData?.value ??
        item.thumbnailPath ??
        ref.watch(itemArtworkPathProvider(item)).asData?.value;
    Widget placeholder() => ColoredBox(
      color: Color.alphaBlend(
        Theme.of(context).colorScheme.primary.withValues(alpha: .08),
        Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Center(
        child: Icon(
          MediaVisuals.icon(item),
          size: 52,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .6),
        ),
      ),
    );
    if (item.filePath.startsWith('remote:'))
      return RemoteItemArtwork(
        item: item,
        placeholder: placeholder(),
        fit: fit,
      );
    if (path == null || path.isEmpty || path.startsWith('remote:')) {
      return placeholder();
    }
    return LayoutBuilder(
      builder: (context, box) => Image.file(
        File(path),
        fit: fit,
        cacheWidth: (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, MediaVisuals.artworkDecodeWidth),
        errorBuilder: (_, _, _) => placeholder(),
      ),
    );
  }
}

class CinematicMediaCard extends StatefulWidget {
  const CinematicMediaCard({
    super.key,
    required this.item,
    required this.onDetails,
    required this.onOpen,
    this.progressPercent,
    this.displayTitle,
    this.subtitle,
  });
  final Item item;
  final VoidCallback onDetails, onOpen;
  final double? progressPercent;
  final String? displayTitle, subtitle;
  @override
  State<CinematicMediaCard> createState() => _CinematicMediaCardState();
}

class _CinematicMediaCardState extends State<CinematicMediaCard> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final title = cleanDisplayTitle(
      widget.displayTitle ?? item.userTitle ?? item.title,
    );
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.quick),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _focused ? scheme.primary : scheme.outlineVariant,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: scheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onDetails,
                onFocusChange: (value) => setState(() => _focused = value),
                child: Semantics(
                  button: true,
                  label: 'Details for $title',
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CinematicArtwork(item: item),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            child: Text(
                              item.filename.split('.').last.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: IconButton.filled(
                          tooltip: '${MediaVisuals.action(item)} $title',
                          onPressed: item.unavailable ? null : widget.onOpen,
                          icon: Icon(
                            MediaVisuals.isReading(item)
                                ? Icons.menu_book_rounded
                                : item.itemType == 'image'
                                ? Icons.open_in_full
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),
                      if (item.unavailable)
                        const Center(
                          child: Icon(Icons.cloud_off, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Tooltip(
                  message: item.filename,
                  child: Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            if (widget.progressPercent != null)
              LinearProgressIndicator(
                value: (widget.progressPercent! / 100).clamp(0, 1),
                minHeight: 3,
                semanticsLabel: '$title progress',
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lazy cards and independent horizontal scroll state for each deterministic row.
class CinematicMediaRow extends StatefulWidget {
  const CinematicMediaRow({
    super.key,
    required this.title,
    required this.items,
    required this.onDetails,
    required this.onOpen,
    this.displayTitles = const {},
    this.progress = const {},
    this.compact = false,
  });
  final String title;
  final bool compact;
  final List<Item> items;
  final Map<String, String> displayTitles;
  final Map<String, double> progress;
  final ValueChanged<Item> onDetails, onOpen;
  @override
  State<CinematicMediaRow> createState() => _CinematicMediaRowState();
}

class _CinematicMediaRowState extends State<CinematicMediaRow> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final target =
        (_scroll.offset + direction * _scroll.position.viewportDimension * .8)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: AppMotion.resolve(context, AppMotion.standard),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            if (widget.items.length > 1)
              IconButton(
                tooltip: 'Previous in ${widget.title}',
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
            if (widget.items.length > 1)
              IconButton(
                tooltip: 'Next in ${widget.title}',
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          height: (widget.compact ? 140 : 235) + 80 * scale,
          child: ListView.separated(
            key: PageStorageKey('media-row-${widget.title}'),
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
            itemBuilder: (context, i) {
              final item = widget.items[i];
              final width = MediaVisuals.isListening(item)
                  ? 235.0
                  : item.itemType == 'image'
                  ? 300.0
                  : 176.0;
              return SizedBox(
                width: widget.compact ? 148 : width,
                child: CinematicMediaCard(
                  key: ValueKey(item.id),
                  item: item,
                  displayTitle: widget.displayTitles[item.id],
                  progressPercent: widget.progress[item.id],
                  onDetails: () => widget.onDetails(item),
                  onOpen: () => widget.onOpen(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FeaturedMedia extends StatelessWidget {
  const FeaturedMedia({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onDetails,
  });
  final Item item;
  final VoidCallback onOpen, onDetails;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.xl),
    child: Stack(
      children: [
        Positioned.fill(child: CinematicArtwork(item: item)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xff111111).withValues(alpha: .98),
                  const Color(0xff111111).withValues(alpha: .78),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(
            AppBreakpoints.isCompact(context) ? AppSpace.lg : AppSpace.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200, maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'FROM YOUR LIBRARY',
                  style: TextStyle(
                    color: Color(0xffffbd80),
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  cleanDisplayTitle(item.userTitle ?? item.title),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '${item.itemType.toUpperCase()} · ${item.filePath.startsWith('remote:') ? 'From your server' : 'In your local library'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: AppSpace.lg),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: item.unavailable ? null : onOpen,
                      icon: Icon(
                        MediaVisuals.isReading(item)
                            ? Icons.menu_book
                            : Icons.play_arrow,
                      ),
                      label: Text(MediaVisuals.action(item)),
                    ),
                    OutlinedButton.icon(
                      onPressed: onDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// A real member supplies group artwork; missing artwork uses the same honest
/// fallback as individual titles. Group navigation never starts playback.
class CinematicGroupCard extends StatelessWidget {
  const CinematicGroupCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.item,
    this.icon = Icons.collections_bookmark_outlined,
  });
  final String title, subtitle;
  final Item? item;
  final IconData icon;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Semantics(
        button: true,
        label: '$title, $subtitle',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item != null)
                    CinematicArtwork(item: item!)
                  else
                    ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Icon(icon, size: 48),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      radius: 16,
                      child: Icon(icon, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
