import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import 'study_ui.dart';
import 'item_artwork.dart';

enum LibraryCardLayout { grid, list }

class LibraryCard extends StatelessWidget {
  const LibraryCard({
    super.key,
    required this.library,
    required this.stats,
    required this.onTap,
    this.onRescan,
    this.onRemove,
    this.layout = LibraryCardLayout.grid,
  });

  final Library library;
  final Future<LibraryStats> stats;
  final VoidCallback onTap;
  final VoidCallback? onRescan;
  final VoidCallback? onRemove;
  final LibraryCardLayout layout;

  @override
  Widget build(BuildContext context) {
    return layout == LibraryCardLayout.list ? _list(context) : _grid(context);
  }

  Widget _grid(BuildContext context) {
    return StudySurface(
      onTap: onTap,
      semanticLabel: 'Open ${cleanDisplayTitle(library.title)} library',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                LibraryArtwork(
                  library: library,
                  size: double.infinity,
                  radius: 0,
                ),
                Positioned(
                  top: AppSpace.xs,
                  right: AppSpace.xs,
                  child: _actions(context),
                ),
                if (library.unavailable)
                  const Positioned(
                    left: AppSpace.sm,
                    bottom: AppSpace.sm,
                    child: StudyStatusBadge(
                      label: 'Folder unavailable',
                      icon: Icons.folder_off_rounded,
                      tone: StudyStatusTone.error,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanDisplayTitle(library.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  library.description.trim().isEmpty
                      ? 'Media library'
                      : library.description.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpace.md),
                _stats(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    return StudySurface(
      onTap: onTap,
      semanticLabel: 'Open ${cleanDisplayTitle(library.title)} library',
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          LibraryArtwork(library: library, size: 76),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cleanDisplayTitle(library.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (library.unavailable) ...[
                      const SizedBox(width: AppSpace.xs),
                      const StudyStatusBadge(
                        label: 'Unavailable',
                        icon: Icons.folder_off_rounded,
                        tone: StudyStatusTone.error,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.xxs),
                StudyMeta(
                  items: [
                    library.description.trim().isEmpty
                        ? 'Local library'
                        : library.description.trim(),
                    if (library.lastScannedAt != null)
                      'Scanned ${_relativeTime(library.lastScannedAt!)}',
                  ],
                  maxLines: 1,
                ),
                const SizedBox(height: AppSpace.sm),
                _stats(context),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          _actions(context),
        ],
      ),
    );
  }

  Widget _stats(BuildContext context) {
    return FutureBuilder<LibraryStats>(
      future: stats,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (value == null) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudySkeleton(height: 7),
              SizedBox(height: AppSpace.xs),
              StudySkeleton(width: 150, height: 13),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudyMeta(
              items: [
                '${value.totalItems} ${value.totalItems == 1 ? 'item' : 'items'}',
                if (value.completedItems > 0)
                  '${value.completedItems} finished',
                if (value.inProgressItems > 0)
                  '${value.inProgressItems} in progress',
              ],
              maxLines: 1,
            ),
          ],
        );
      },
    );
  }

  Widget _actions(BuildContext context) {
    return Material(
      color: context.studyColors.surfaceRaised.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: PopupMenuButton<String>(
        tooltip: 'Library actions',
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (value) {
          if (value == 'rescan') onRescan?.call();
          if (value == 'remove') onRemove?.call();
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'rescan',
            enabled: onRescan != null,
            child: const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.refresh_rounded),
              title: Text('Rescan library'),
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            enabled: onRemove != null,
            child: const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Remove library'),
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(int milliseconds) {
    final difference = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(milliseconds),
    );
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    return '${difference.inDays} d ago';
  }
}
