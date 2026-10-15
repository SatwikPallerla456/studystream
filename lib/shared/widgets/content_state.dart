import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'study_ui.dart';

enum ContentStateTone { neutral, error, warning, success }

class ContentState extends StatelessWidget {
  const ContentState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.secondaryAction,
    this.tone = ContentStateTone.neutral,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Widget? secondaryAction;
  final ContentStateTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      ContentStateTone.error => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      ContentStateTone.warning => (
        context.studyColors.warningContainer,
        context.studyColors.warning,
      ),
      ContentStateTone.success => (
        context.studyColors.successContainer,
        context.studyColors.success,
      ),
      ContentStateTone.neutral => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
    };

    return Semantics(
      liveRegion: tone == ContentStateTone.error,
      child: StudySurface(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.all(compact ? AppSpace.md : AppSpace.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  minHeight: constraints.hasBoundedHeight
                      ? (constraints.maxHeight -
                                (compact ? AppSpace.md : AppSpace.xl) * 2)
                            .clamp(0.0, double.infinity)
                      : 0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 52 : 64,
                      height: compact ? 52 : 64,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: compact ? 26 : 30,
                        color: foreground,
                      ),
                    ),
                    SizedBox(height: compact ? AppSpace.md : AppSpace.lg),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (action != null || secondaryAction != null) ...[
                      const SizedBox(height: AppSpace.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpace.xs,
                        runSpacing: AppSpace.xs,
                        children: [?action, ?secondaryAction],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContentLoadingState extends StatelessWidget {
  const ContentLoadingState({super.key, this.label = 'Loading content'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: StudySurface(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StudySkeleton(width: 180, height: 22),
              const SizedBox(height: AppSpace.md),
              const StudySkeleton(height: 15),
              const SizedBox(height: AppSpace.xs),
              const StudySkeleton(width: 280, height: 15),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: const [
                  Expanded(child: StudySkeleton(height: 76)),
                  SizedBox(width: AppSpace.sm),
                  Expanded(child: StudySkeleton(height: 76)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
