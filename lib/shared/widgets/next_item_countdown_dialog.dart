import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'study_ui.dart';

enum NextCountdownAction { backToLibrary, startNow, autoStart, dismissed }

Future<NextCountdownAction> showNextItemCountdownDialog({
  required BuildContext context,
  required String nextTitle,
  required String nextType,
  int seconds = 6,
}) async {
  final result = await showStudyAdaptiveModal<NextCountdownAction>(
    context: context,
    dismissible: false,
    builder: (_) => NextItemCountdownDialog(
      nextTitle: nextTitle,
      nextType: nextType,
      seconds: seconds,
    ),
  );

  return result ?? NextCountdownAction.dismissed;
}

class NextItemCountdownDialog extends StatefulWidget {
  final String nextTitle;
  final String nextType;
  final int seconds;

  const NextItemCountdownDialog({
    super.key,
    required this.nextTitle,
    required this.nextType,
    required this.seconds,
  });

  @override
  State<NextItemCountdownDialog> createState() =>
      _NextItemCountdownDialogState();
}

class _NextItemCountdownDialogState extends State<NextItemCountdownDialog> {
  Timer? _timer;
  late int _remaining;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resolved || !mounted) {
        timer.cancel();
        return;
      }

      if (_remaining <= 1) {
        _resolve(NextCountdownAction.autoStart);
        return;
      }

      setState(() {
        _remaining--;
      });
    });
  }

  void _resolve(NextCountdownAction action) {
    if (_resolved) return;
    _resolved = true;
    _timer?.cancel();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(action);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Icons.play_circle_outline;
      case 'audio':
        return Icons.headphones;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'link':
        return Icons.link;
      case 'html':
        return Icons.language;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.seconds == 0
        ? 1.0
        : (widget.seconds - _remaining) / widget.seconds;
    final colors = Theme.of(context).colorScheme;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: widget.nextType == 'done'
                    ? context.studyColors.successContainer
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(
                widget.nextType == 'done'
                    ? Icons.done_all_rounded
                    : _iconForType(widget.nextType),
                size: 34,
                color: widget.nextType == 'done'
                    ? context.studyColors.success
                    : colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              widget.nextType == 'done' ? 'Library complete' : 'Up next',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              widget.nextTitle,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.xs),
            StudyStatusBadge(
              label: widget.nextType == 'done'
                  ? 'All lessons finished'
                  : widget.nextType.toUpperCase(),
              icon: widget.nextType == 'done'
                  ? Icons.check_rounded
                  : _iconForType(widget.nextType),
              tone: widget.nextType == 'done'
                  ? StudyStatusTone.success
                  : StudyStatusTone.primary,
            ),
            const SizedBox(height: AppSpace.lg),
            StudyProgress(
              value: progress.clamp(0.0, 1.0),
              label: 'Auto-advance countdown',
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              widget.nextType == 'done'
                  ? 'Returning to your library in $_remaining seconds…'
                  : 'Starting in $_remaining seconds…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: [
                TextButton(
                  onPressed: () => _resolve(NextCountdownAction.dismissed),
                  child: const Text('Pause countdown'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _resolve(NextCountdownAction.backToLibrary),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to library'),
                ),
                if (widget.nextType != 'done')
                  FilledButton.icon(
                    onPressed: () => _resolve(NextCountdownAction.startNow),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start now'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return AppBreakpoints.isCompact(context)
        ? SafeArea(top: false, child: content)
        : Dialog(child: content);
  }
}
