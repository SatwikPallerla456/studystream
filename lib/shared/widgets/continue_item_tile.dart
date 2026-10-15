import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import 'study_ui.dart';
import 'item_artwork.dart';

class ContinueItemTile extends StatelessWidget {
  const ContinueItemTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.compact = false,
  });

  final ContinueEntry entry;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final value = (entry.progressPercent / 100).clamp(0.0, 1.0);
    final title = cleanDisplayTitle(entry.item.userTitle ?? entry.item.title);
    return StudySurface(
      onTap: onTap,
      semanticLabel:
          'Continue $title, ${entry.progressPercent.toStringAsFixed(0)} percent complete',
      padding: EdgeInsets.all(compact ? AppSpace.sm : AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ItemArtwork(item: entry.item, size: compact ? 58 : 76),
              if (!entry.item.unavailable &&
                  (entry.item.itemType == 'video' ||
                      entry.item.itemType == 'audio'))
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.studyColors.player.withValues(alpha: .82),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xxs),
                StudyMeta(
                  items: [
                    _typeLabel(entry.item.itemType),
                    _relativeTime(entry.lastOpenedAt),
                  ],
                  maxLines: 1,
                ),
                const SizedBox(height: AppSpace.sm),
                StudyProgress(
                  value: value,
                  label: 'Lesson progress',
                  showPercentage: true,
                  height: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _typeLabel(String type) => switch (type) {
    'video' => 'Watching',
    'audio' => 'Listening',
    'pdf' => 'Reading',
    _ => type.toUpperCase(),
  };

  static String _relativeTime(int milliseconds) {
    if (milliseconds <= 0) return 'Recently opened';
    final difference = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(milliseconds),
    );
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} d ago';
    return 'Recently opened';
  }
}
