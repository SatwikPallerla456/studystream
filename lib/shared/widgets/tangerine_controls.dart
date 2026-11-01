import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart' show SpringSimulation;

import '../../core/theme/app_theme.dart';

/// Paint-only feedback around an existing accessible control. Activation stays
/// with the child, so scrolling, keyboard actions and nested buttons keep their
/// normal gesture ownership. No artwork or page is duplicated for the effect.
class TangerineInteraction extends StatefulWidget {
  const TangerineInteraction({
    super.key,
    required this.child,
    this.enabled = true,
    this.lift = 0,
    this.pressedScale = .98,
  });

  final Widget child;
  final bool enabled;
  final double lift, pressedScale;

  @override
  State<TangerineInteraction> createState() => _TangerineInteractionState();
}

class _TangerineInteractionState extends State<TangerineInteraction>
    with SingleTickerProviderStateMixin {
  final _pointers = <int, Offset>{};
  bool _hovered = false;
  late final _pressure = AnimationController.unbounded(vsync: this);

  void _settle() {
    final target = widget.enabled && _pointers.isNotEmpty ? 1.0 : 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pressure.stop();
      _pressure.value = 0;
      return;
    }
    if ((_pressure.value - target).abs() < .001 &&
        _pressure.velocity.abs() < .001) {
      _pressure.stop();
      _pressure.value = target;
      return;
    }
    _pressure.animateWith(
      SpringSimulation(
        AppMotion.feedbackSpring,
        _pressure.value,
        target,
        _pressure.velocity,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settle();
  }

  @override
  void dispose() {
    _pressure.dispose();
    super.dispose();
  }

  void _release(int pointer) {
    if (_pointers.remove(pointer) != null && mounted) {
      setState(() {});
      _settle();
    }
  }

  @override
  void didUpdateWidget(TangerineInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pointers.clear();
      _hovered = false;
      _pressure.stop();
      _pressure.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final pressed = widget.enabled && _pointers.isNotEmpty;
    return MouseRegion(
      onEnter: (_) {
        if (widget.enabled) setState(() => _hovered = true);
      },
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (event) {
          if (widget.enabled) {
            setState(() => _pointers[event.pointer] = event.position);
            _settle();
          }
        },
        onPointerMove: (event) {
          final origin = _pointers[event.pointer];
          if (origin != null && (event.position - origin).distance > 12) {
            _release(event.pointer);
          }
        },
        onPointerUp: (event) => _release(event.pointer),
        onPointerCancel: (event) => _release(event.pointer),
        child: AnimatedContainer(
          duration: AppMotion.resolve(context, AppMotion.quick),
          curve: AppMotion.release,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(
              0,
              !reduced && _hovered && !pressed ? -widget.lift : 0,
              0,
              1,
            ),
          child: AnimatedBuilder(
            animation: _pressure,
            child: widget.child,
            builder: (context, child) => Transform.scale(
              scale:
                  1 -
                  (1 - widget.pressedScale) * _pressure.value.clamp(-.1, 1.1),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class TangerineChoice<T> {
  const TangerineChoice({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// A continuous selection surface. The indicator travels between equal slots;
/// large text/narrow windows switch to wrapping choices instead of clipping.
class TangerineSegments<T> extends StatelessWidget {
  const TangerineSegments({
    super.key,
    required this.value,
    required this.choices,
    required this.onChanged,
    required this.label,
  }) : assert(choices.length > 0);

  final T value;
  final List<TangerineChoice<T>> choices;
  final ValueChanged<T>? onChanged;
  final String label;

  void _move(int delta) {
    final index = choices.indexWhere((choice) => choice.value == value);
    onChanged?.call(choices[(index + delta) % choices.length].value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelLarge!;
    final direction = Directionality.of(context);
    final selected = choices.indexWhere((choice) => choice.value == value);
    final radius = BorderRadius.circular(18);
    Widget option(TangerineChoice<T> choice, {bool ownIndicator = false}) {
      final active = choice.value == value;
      return Semantics(
        button: true,
        enabled: onChanged != null,
        selected: active,
        inMutuallyExclusiveGroup: true,
        child: TangerineInteraction(
          enabled: onChanged != null,
          child: Material(
            color: ownIndicator && active
                ? colors.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onChanged == null
                  ? null
                  : () {
                      if (!active) onChanged!(choice.value);
                    },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (choice.icon != null) ...[
                        Icon(
                          choice.icon,
                          size: 19,
                          color: active
                              ? colors.onPrimaryContainer
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          choice.label,
                          style: style.copyWith(
                            color: onChanged == null
                                ? colors.onSurface.withValues(alpha: .38)
                                : active
                                ? colors.onPrimaryContainer
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: label,
      child: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.arrowRight): _MoveChoice(
            direction == TextDirection.rtl ? -1 : 1,
          ),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveChoice(
            direction == TextDirection.rtl ? 1 : -1,
          ),
        },
        child: Actions(
          actions: {
            _MoveChoice: CallbackAction<_MoveChoice>(
              onInvoke: (intent) {
                _move(intent.delta);
                return null;
              },
            ),
          },
          child: LayoutBuilder(
            builder: (context, box) {
              var slot = 80.0;
              for (final choice in choices) {
                final painter = TextPainter(
                  text: TextSpan(text: choice.label, style: style),
                  textDirection: direction,
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                slot = math.max(
                  slot,
                  painter.width + 40 + (choice.icon == null ? 0 : 27),
                );
                painter.dispose();
              }
              final width = slot * choices.length + 8;
              if (box.maxWidth < width) {
                return Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final choice in choices)
                      option(choice, ownIndicator: true),
                  ],
                );
              }
              return Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                heightFactor: 1,
                child: SizedBox(
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.studyColors.surfaceStrong.withValues(
                        alpha: .45,
                      ),
                      borderRadius: radius,
                    ),
                    child: Stack(
                      children: [
                        if (selected >= 0)
                          AnimatedPositionedDirectional(
                            duration: AppMotion.resolve(
                              context,
                              AppMotion.standard,
                            ),
                            curve: AppMotion.settle,
                            start: 4 + selected * slot,
                            top: 4,
                            bottom: 4,
                            width: slot,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              for (final choice in choices)
                                SizedBox(width: slot, child: option(choice)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MoveChoice extends Intent {
  const _MoveChoice(this.delta);
  final int delta;
}

/// A labelled, inline home for secondary actions. The trigger stays in place
/// while the action surface unfolds; no overlay obscures the current content.
class TangerineActionGroup extends StatefulWidget {
  const TangerineActionGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  State<TangerineActionGroup> createState() => _TangerineActionGroupState();
}

class _TangerineActionGroupState extends State<TangerineActionGroup> {
  bool _expanded = false;
  final _trigger = FocusNode();

  @override
  void dispose() {
    _trigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      if (_expanded)
        const SingleActivator(LogicalKeyboardKey.escape): () {
          setState(() => _expanded = false);
          _trigger.requestFocus();
        },
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          expanded: _expanded,
          child: TangerineInteraction(
            child: TextButton.icon(
              focusNode: _trigger,
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                minimumSize: const Size(48, 48),
                shape: const StadiumBorder(),
              ),
              icon: Icon(widget.icon, size: 20),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(widget.title)),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? .5 : 0,
                    duration: AppMotion.resolve(context, AppMotion.standard),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.resolve(context, AppMotion.emphasized),
          curve: AppMotion.settle,
          alignment: AlignmentDirectional.topStart,
          child: !_expanded
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final child in widget.children)
                        TangerineInteraction(child: child),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}

/// Small selectors unfold in place, preserving spatial context and keyboard
/// focus. Choosing a value collapses the surface; Escape also closes it.
class TangerineChoicePicker<T> extends StatefulWidget {
  const TangerineChoicePicker({
    super.key,
    required this.value,
    required this.choices,
    required this.onChanged,
    required this.label,
    this.icon,
  });
  final T value;
  final List<TangerineChoice<T>> choices;
  final ValueChanged<T>? onChanged;
  final String label;
  final IconData? icon;

  @override
  State<TangerineChoicePicker<T>> createState() =>
      _TangerineChoicePickerState<T>();
}

class _TangerineChoicePickerState<T> extends State<TangerineChoicePicker<T>> {
  bool _expanded = false;
  final _trigger = FocusNode();
  final _choicesScroll = ScrollController();

  @override
  void dispose() {
    _trigger.dispose();
    _choicesScroll.dispose();
    super.dispose();
  }

  void _close() {
    setState(() => _expanded = false);
    _trigger.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = widget.choices
        .where((choice) => choice.value == widget.value)
        .firstOrNull;
    return CallbackShortcuts(
      bindings: {
        if (_expanded) const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            expanded: _expanded,
            child: TangerineInteraction(
              child: TextButton(
                focusNode: _trigger,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: colors.onSurface,
                  backgroundColor: _expanded
                      ? colors.primaryContainer.withValues(alpha: .4)
                      : null,
                  shape: const StadiumBorder(),
                ),
                onPressed: widget.onChanged == null
                    ? null
                    : () {
                        _trigger.requestFocus();
                        setState(() => _expanded = !_expanded);
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        '${widget.label}: ${current?.label ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: AppMotion.resolve(context, AppMotion.standard),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            alignment: AlignmentDirectional.topStart,
            duration: AppMotion.resolve(context, AppMotion.emphasized),
            curve: AppMotion.settle,
            child: !_expanded
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (MediaQuery.sizeOf(context).height * .3)
                            .clamp(96.0, 280.0),
                      ),
                      child: Scrollbar(
                        controller: _choicesScroll,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _choicesScroll,
                          primary: false,
                          padding: const EdgeInsetsDirectional.only(end: 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final choice in widget.choices)
                                Semantics(
                                  selected: choice.value == widget.value,
                                  inMutuallyExclusiveGroup: true,
                                  child: TangerineInteraction(
                                    child: ChoiceChip(
                                      label: Text(choice.label),
                                      showCheckmark: choice.icon == null,
                                      avatar: choice.icon == null
                                          ? null
                                          : Icon(choice.icon, size: 18),
                                      selected: choice.value == widget.value,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.padded,
                                      onSelected: widget.onChanged == null
                                          ? null
                                          : (_) {
                                              _close();
                                              if (choice.value != widget.value)
                                                widget.onChanged?.call(
                                                  choice.value,
                                                );
                                            },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// An unboxed preference section. Draft state survives collapse, while hidden
/// controls are excluded from focus/semantics and their tickers are disabled.
class TangerinePreferenceSection extends StatefulWidget {
  const TangerinePreferenceSection({
    super.key,
    required this.title,
    this.description = '',
    this.icon = Icons.tune_rounded,
    required this.child,
    this.trailing,
    this.collapsible = false,
  });
  final String title, description;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final bool collapsible;
  @override
  State<TangerinePreferenceSection> createState() =>
      _TangerinePreferenceSectionState();
}

class _TangerinePreferenceSectionState
    extends State<TangerinePreferenceSection> {
  bool _expanded = false;
  final _trigger = FocusNode();
  @override
  void dispose() {
    _trigger.dispose();
    super.dispose();
  }

  void _toggle() {
    _trigger.requestFocus();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(widget.icon, color: colors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (widget.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 12),
          widget.trailing!,
        ],
        if (widget.collapsible) ...[
          const SizedBox(width: 12),
          AnimatedRotation(
            turns: _expanded ? .5 : 0,
            duration: AppMotion.resolve(context, AppMotion.standard),
            child: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ],
    );
    return CallbackShortcuts(
      bindings: {
        if (widget.collapsible && _expanded)
          const SingleActivator(LogicalKeyboardKey.escape): _toggle,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.collapsible)
            Semantics(
              expanded: _expanded,
              child: TangerineInteraction(
                pressedScale: .995,
                child: TextButton(
                  focusNode: _trigger,
                  style: TextButton.styleFrom(
                    alignment: AlignmentDirectional.centerStart,
                    foregroundColor: colors.onSurface,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _toggle,
                  child: heading,
                ),
              ),
            )
          else
            Padding(padding: const EdgeInsets.all(16), child: heading),
          AnimatedSize(
            duration: AppMotion.resolve(context, AppMotion.emphasized),
            curve: AppMotion.settle,
            alignment: AlignmentDirectional.topStart,
            child: Visibility(
              visible: !widget.collapsible || _expanded,
              maintainState: true,
              child: ExcludeFocus(
                excluding: widget.collapsible && !_expanded,
                child: ExcludeSemantics(
                  excluding: widget.collapsible && !_expanded,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps a growing inline control area from consuming the scrollable results.
/// Both scroll owners have bounded viewports and independent lifetimes.
class TangerineWorkbenchLayout extends StatefulWidget {
  const TangerineWorkbenchLayout({
    super.key,
    required this.header,
    required this.body,
  });
  final List<Widget> header;
  final Widget body;
  @override
  State<TangerineWorkbenchLayout> createState() =>
      _TangerineWorkbenchLayoutState();
}

class _TangerineWorkbenchLayoutState extends State<TangerineWorkbenchLayout> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: box.maxHeight * .58),
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              primary: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.header,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: widget.body),
      ],
    ),
  );
}

class TangerineBoundedList extends StatefulWidget {
  const TangerineBoundedList({
    super.key,
    required this.children,
    this.maxHeight = 280,
  });
  final List<Widget> children;
  final double maxHeight;
  @override
  State<TangerineBoundedList> createState() => _TangerineBoundedListState();
}

class _TangerineBoundedListState extends State<TangerineBoundedList> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: widget.maxHeight),
    child: Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      child: ListView(
        controller: _scroll,
        primary: false,
        shrinkWrap: true,
        children: widget.children,
      ),
    ),
  );
}
