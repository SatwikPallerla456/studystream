import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class StudyPage extends StatelessWidget {
  const StudyPage({
    super.key,
    required this.child,
    this.maxWidth = 1360,
    this.scrollable = true,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final resolvedPadding =
        padding ??
        EdgeInsets.fromLTRB(
          width < AppBreakpoints.compact
              ? AppSpace.md
              : width < AppBreakpoints.expanded
              ? AppSpace.lg
              : AppSpace.xl,
          width < AppBreakpoints.compact ? AppSpace.md : AppSpace.lg,
          width < AppBreakpoints.compact
              ? AppSpace.md
              : width < AppBreakpoints.expanded
              ? AppSpace.lg
              : AppSpace.xl,
          AppSpace.xxxl,
        );

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );
    return Material(
      color: Colors.transparent,
      child: scrollable
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }
}

class StudyPageHeader extends StatelessWidget {
  const StudyPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.actions = const [],
  });

  final String title;
  final String? eyebrow;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
          ],
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          if (description != null) ...[
            const SizedBox(height: AppSpace.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Text(
                description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 680;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: actions,
                ),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: AppSpace.lg),
              Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: actions,
              ),
            ],
          ],
        );
      },
    );
  }
}

class StudySectionHeader extends StatelessWidget {
  const StudySectionHeader({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: compact
                    ? Theme.of(context).textTheme.titleLarge
                    : Theme.of(context).textTheme.headlineSmall,
              ),
              if (description != null) ...[
                const SizedBox(height: AppSpace.xxs),
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpace.md),
          trailing!,
        ],
      ],
    );
  }
}

class StudySurface extends StatelessWidget {
  const StudySurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
    this.selected = false,
    this.emphasized = false,
    this.radius = AppRadius.md,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final bool emphasized;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final extras = context.studyColors;
    final content = AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.standard),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer.withValues(alpha: .48)
            : emphasized
            ? extras.surfaceSubtle
            : extras.surfaceRaised,
        border: Border.all(
          color: selected ? colors.primary : extras.outlineSoft,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: emphasized ? AppElevation.level1 : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          focusColor: extras.focusRing.withValues(alpha: .14),
          hoverColor: extras.hover,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return semanticLabel == null
        ? content
        : Semantics(
            button: onTap != null,
            label: semanticLabel,
            child: content,
          );
  }
}

class StudySection extends StatelessWidget {
  const StudySection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StudySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                _IconWell(icon: icon!),
                const SizedBox(width: AppSpace.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (description != null) ...[
                      const SizedBox(height: AppSpace.xxs),
                      Text(
                        description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          child,
        ],
      ),
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 22,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

enum StudyStatusTone { neutral, primary, success, warning, error, info }

class StudyStatusBadge extends StatelessWidget {
  const StudyStatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = StudyStatusTone.neutral,
  });

  final String label;
  final IconData? icon;
  final StudyStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final extras = context.studyColors;
    final (background, foreground) = switch (tone) {
      StudyStatusTone.primary => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      StudyStatusTone.success => (extras.successContainer, extras.success),
      StudyStatusTone.warning => (extras.warningContainer, extras.warning),
      StudyStatusTone.error => (colors.errorContainer, colors.onErrorContainer),
      StudyStatusTone.info => (extras.infoContainer, extras.info),
      StudyStatusTone.neutral => (
        extras.surfaceStrong,
        colors.onSurfaceVariant,
      ),
    };
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: AppSpace.xxs),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudyProgress extends StatelessWidget {
  const StudyProgress({
    super.key,
    required this.value,
    this.label,
    this.height = 8,
    this.showPercentage = false,
  });

  final double value;
  final String? label;
  final double height;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final safe = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final percentage = '${(safe * 100).round()}%';
    return Semantics(
      label: label ?? 'Progress',
      value: percentage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showPercentage) ...[
            Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(
                      label!,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  percentage,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              duration: AppMotion.resolve(context, AppMotion.standard),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: safe),
              builder: (context, value, _) =>
                  LinearProgressIndicator(value: value, minHeight: height),
            ),
          ),
        ],
      ),
    );
  }
}

class StudySearchField extends StatelessWidget {
  const StudySearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }
}

class StudySkeleton extends StatefulWidget {
  const StudySkeleton({
    super.key,
    this.height = 18,
    this.width = double.infinity,
    this.radius = AppRadius.xs,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<StudySkeleton> createState() => _StudySkeletonState();
}

class _StudySkeletonState extends State<StudySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.stop();
      _controller.value = .5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.studyColors.surfaceStrong;
    return FadeTransition(
      opacity: Tween<double>(begin: .55, end: 1).animate(_controller),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class StudyArtwork extends StatelessWidget {
  const StudyArtwork({
    super.key,
    this.path,
    required this.kind,
    this.size = 64,
    this.radius = AppRadius.sm,
    this.unavailable = false,
  });

  final String? path;
  final String kind;
  final double size;
  final double radius;
  final bool unavailable;

  IconData get _icon {
    if (unavailable) return Icons.cloud_off_rounded;
    return switch (kind.toLowerCase()) {
      'library' => Icons.video_library_rounded,
      'video' => Icons.play_circle_fill_rounded,
      'audio' => Icons.graphic_eq_rounded,
      'pdf' => Icons.menu_book_rounded,
      'image' => Icons.image_rounded,
      'html' || 'link' => Icons.language_rounded,
      'text' || 'txt' => Icons.article_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconSize = size.isFinite ? size * .42 : 44.0;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: unavailable ? colors.errorContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        _icon,
        size: iconSize,
        color: unavailable
            ? colors.onErrorContainer
            : colors.onPrimaryContainer,
      ),
    );
    if (path == null || path!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(path!),
        cacheWidth: size.isFinite
            ? (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(
                1,
                1200,
              )
            : 1200,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class StudyMeta extends StatelessWidget {
  const StudyMeta({super.key, required this.items, this.maxLines = 2});

  final List<String> items;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final visible = items.where((value) => value.trim().isNotEmpty).toList();
    return Text(
      visible.join('  •  '),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.studyColors.textMuted),
    );
  }
}

class StudyDivider extends StatelessWidget {
  const StudyDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(indent: indent, endIndent: 0);
}

class StudyShortcutHint extends StatelessWidget {
  const StudyShortcutHint({super.key, required this.keys});

  final String keys;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.studyColors.surfaceSubtle,
        border: Border.all(color: context.studyColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(keys, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

Future<T?> showStudyAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
  List<ChangeNotifier> disposeOnClose = const [],
}) {
  if (AppBreakpoints.isCompact(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _ModalResources(
          resources: disposeOnClose,
          child: builder(sheetContext),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    builder: (context) =>
        _ModalResources(resources: disposeOnClose, child: builder(context)),
  );
}

class _ModalResources extends StatefulWidget {
  const _ModalResources({required this.resources, required this.child});
  final List<ChangeNotifier> resources;
  final Widget child;
  @override
  State<_ModalResources> createState() => _ModalResourcesState();
}

class _ModalResourcesState extends State<_ModalResources> {
  @override
  void dispose() {
    for (final resource in widget.resources) {
      resource.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class StudyConfirmDialog extends StatelessWidget {
  const StudyConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.icon = Icons.help_outline_rounded,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconWell(icon: icon),
            const SizedBox(height: AppSpace.md),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpace.xs),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpace.lg),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSpace.xs),
                FilledButton(
                  style: destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                        )
                      : null,
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return AppBreakpoints.isCompact(context)
        ? SafeArea(child: content)
        : Dialog(child: content);
  }
}

class StudyModalFrame extends StatelessWidget {
  const StudyModalFrame({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.icon,
    this.primaryAction,
    this.secondaryAction,
    this.maxWidth = 520,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget child;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  _IconWell(icon: icon!),
                  const SizedBox(width: AppSpace.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (description != null) ...[
                        const SizedBox(height: AppSpace.xxs),
                        Text(
                          description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Flexible(child: SingleChildScrollView(child: child)),
            if (primaryAction != null || secondaryAction != null) ...[
              const SizedBox(height: AppSpace.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ?secondaryAction,
                  if (secondaryAction != null && primaryAction != null)
                    const SizedBox(width: AppSpace.xs),
                  ?primaryAction,
                ],
              ),
            ],
          ],
        ),
      ),
    );
    return AppBreakpoints.isCompact(context)
        ? SafeArea(top: false, child: content)
        : Dialog(child: content);
  }
}
