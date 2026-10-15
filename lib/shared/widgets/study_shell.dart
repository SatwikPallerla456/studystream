import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'study_ui.dart';

class StudyShellDestination {
  const StudyShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class StudyShell extends StatelessWidget {
  const StudyShell({
    super.key,
    required this.index,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
  });

  final int index;
  final ValueChanged<int> onDestinationSelected;
  final List<StudyShellDestination> destinations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const destinationKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ];
    final shortcuts = <ShortcutActivator, Intent>{
      for (var i = 0; i < destinations.length; i++)
        SingleActivator(destinationKeys[i], alt: true):
            _SelectDestinationIntent(i),
    };
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          _SelectDestinationIntent: CallbackAction<_SelectDestinationIntent>(
            onInvoke: (intent) {
              onDestinationSelected(intent.index);
              return null;
            },
          ),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < AppBreakpoints.compact) {
              return _CompactShell(
                index: index,
                onDestinationSelected: onDestinationSelected,
                destinations: destinations,
                child: child,
              );
            }
            if (constraints.maxWidth < AppBreakpoints.expanded) {
              return _RailShell(
                index: index,
                onDestinationSelected: onDestinationSelected,
                destinations: destinations,
                child: child,
              );
            }
            return _SidebarShell(
              index: index,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.index,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
  });

  final int index;
  final ValueChanged<int> onDestinationSelected;
  final List<StudyShellDestination> destinations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: AppSpace.md,
        title: const _Brand(compact: true),
      ),
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 80 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 2,
          selectedIndex: index,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
                tooltip:
                    '${destination.label} · Alt+${destinations.indexOf(destination) + 1}',
              ),
          ],
        ),
      ),
    );
  }
}

class _RailShell extends StatelessWidget {
  const _RailShell({
    required this.index,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
  });

  final int index;
  final ValueChanged<int> onDestinationSelected;
  final List<StudyShellDestination> destinations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.studyColors.surfaceRaised,
              border: Border(
                right: BorderSide(color: context.studyColors.outlineSoft),
              ),
            ),
            child: SafeArea(
              right: false,
              child: NavigationRail(
                minWidth: 80,
                labelType: NavigationRailLabelType.all,
                selectedIndex: index,
                onDestinationSelected: onDestinationSelected,
                leading: const Padding(
                  padding: EdgeInsets.only(bottom: AppSpace.lg),
                  child: _Brand(compact: true),
                ),
                destinations: [
                  for (var i = 0; i < destinations.length; i++)
                    NavigationRailDestination(
                      icon: Tooltip(
                        message: '${destinations[i].label} · Alt+${i + 1}',
                        child: Icon(destinations[i].icon),
                      ),
                      selectedIcon: Icon(destinations[i].selectedIcon),
                      label: Text(destinations[i].label),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SidebarShell extends StatelessWidget {
  const _SidebarShell({
    required this.index,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
  });

  final int index;
  final ValueChanged<int> onDestinationSelected;
  final List<StudyShellDestination> destinations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 248 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 8,
            decoration: BoxDecoration(
              color: context.studyColors.surfaceRaised,
              border: Border(
                right: BorderSide(color: context.studyColors.outlineSoft),
              ),
            ),
            child: SafeArea(
              right: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpace.xs),
                      child: _Brand(),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    for (var i = 0; i < destinations.length; i++) ...[
                      _SidebarDestination(
                        destination: destinations[i],
                        selected: i == index,
                        shortcut: 'Alt+${i + 1}',
                        onTap: () => onDestinationSelected(i),
                      ),
                      const SizedBox(height: AppSpace.xxs),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        color: context.studyColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            'Private by design',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpace.xxs),
                          Text(
                            'Your learning files stay where you put them.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.destination,
    required this.selected,
    required this.shortcut,
    required this.onTap,
  });

  final StudyShellDestination destination;
  final bool selected;
  final String shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.quick),
        decoration: BoxDecoration(
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    color: selected
                        ? colors.onPrimaryContainer
                        : context.studyColors.textMuted,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (selected) StudyShortcutHint(keys: shortcut),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      header: true,
      label: 'StudyStream',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.play_arrow_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 26,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: AppSpace.sm),
            Flexible(
              child: Text(
                'StudyStream',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectDestinationIntent extends Intent {
  const _SelectDestinationIntent(this.index);

  final int index;
}
