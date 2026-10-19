import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Keeps rows keyed through edits and reordering, retaining removed content only
/// long enough to fade and collapse it. Initial data appears without a delay.
class StudyAnimatedList<T> extends StatefulWidget {
  const StudyAnimatedList({
    super.key,
    required this.items,
    required this.itemId,
    required this.itemBuilder,
    required this.emptyState,
    this.padding = EdgeInsets.zero,
    this.separatorBuilder,
    this.listBuilder,
  });

  final List<T> items;
  final Object Function(T) itemId;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget emptyState;
  final EdgeInsetsGeometry padding;
  final IndexedWidgetBuilder? separatorBuilder;
  final Widget Function(BuildContext, Widget)? listBuilder;

  @override
  State<StudyAnimatedList<T>> createState() => _StudyAnimatedListState<T>();
}

class _StudyAnimatedListState<T> extends State<StudyAnimatedList<T>> {
  late List<_Entry<T>> _entries;
  bool _animate = false;
  final _removals = <Object, Timer>{};

  @override
  void initState() {
    super.initState();
    _entries = [
      for (final item in widget.items)
        _Entry(id: widget.itemId(item), item: item),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = AppMotion.resolve(context, AppMotion.standard) != Duration.zero;
    if (!_animate) {
      _entries.removeWhere((entry) => !entry.active);
      for (final timer in _removals.values) {
        timer.cancel();
      }
      _removals.clear();
    }
  }

  @override
  void didUpdateWidget(covariant StudyAnimatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = {for (final entry in _entries) entry.id: entry};
    final incomingIds = widget.items.map(widget.itemId).toSet();
    assert(incomingIds.length == widget.items.length, 'Row IDs must be unique');
    for (final id in incomingIds) {
      _removals.remove(id)?.cancel();
    }
    final next = [
      for (final item in widget.items)
        _Entry(
          id: widget.itemId(item),
          item: item,
          entering: _animate && !previous.containsKey(widget.itemId(item)),
        ),
    ];
    if (_animate) {
      for (var index = 0; index < _entries.length; index++) {
        final entry = _entries[index];
        if (!incomingIds.contains(entry.id)) {
          _removals.putIfAbsent(
            entry.id,
            () => Timer(AppMotion.standard, () => _finishRemoval(entry.id)),
          );
          next.insert(
            index.clamp(0, next.length),
            _Entry(id: entry.id, item: entry.item, active: false),
          );
        }
      }
    }
    _entries = next;
  }

  void _finishRemoval(Object id) {
    _removals.remove(id);
    if (!mounted || !_entries.any((e) => e.id == id && !e.active)) return;
    setState(() => _entries.removeWhere((e) => e.id == id && !e.active));
  }

  @override
  void dispose() {
    for (final timer in _removals.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return widget.emptyState;
    final indexes = {
      for (var index = 0; index < _entries.length; index++)
        _entries[index].id: index,
    };
    final list = ListView.builder(
      primary: false,
      padding: widget.padding,
      itemCount: _entries.length,
      findChildIndexCallback: (key) =>
          key is ValueKey<Object> ? indexes[key.value] : null,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return TweenAnimationBuilder<double>(
          key: ValueKey<Object>(entry.id),
          duration: AppMotion.resolve(context, AppMotion.standard),
          curve: Curves.easeOutCubic,
          tween: Tween(
            begin: entry.entering ? 0 : 1,
            end: entry.active ? 1 : 0,
          ),
          child: IgnorePointer(
            ignoring: !entry.active,
            child: ExcludeFocus(
              excluding: !entry.active,
              child: ExcludeSemantics(
                excluding: !entry.active,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.itemBuilder(context, entry.item),
                    if (index < _entries.length - 1 &&
                        widget.separatorBuilder != null)
                      widget.separatorBuilder!(context, index),
                  ],
                ),
              ),
            ),
          ),
          builder: (context, value, child) => ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: value,
              child: Opacity(opacity: value, child: child),
            ),
          ),
        );
      },
    );
    return widget.listBuilder?.call(context, list) ?? list;
  }
}

class _Entry<T> {
  const _Entry({
    required this.id,
    required this.item,
    this.active = true,
    this.entering = false,
  });

  final Object id;
  final T item;
  final bool active;
  final bool entering;
}
