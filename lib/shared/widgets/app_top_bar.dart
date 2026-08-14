import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final bool showHome;
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final List<Widget>? actions;

  const AppTopBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.showHome = true,
    this.onBack,
    this.onHome,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final compact = AppBreakpoints.isCompact(context);
    return AppBar(
      toolbarHeight: compact ? 60 : 68,
      backgroundColor: context.studyColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(color: context.studyColors.outlineSoft),
      ),
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBack ?? () => context.pop(),
              tooltip: 'Back',
            )
          : showHome
          ? IconButton(
              icon: const Icon(Icons.home_outlined),
              onPressed: onHome ?? () => context.go('/'),
              tooltip: 'Home',
            )
          : null,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      centerTitle: false,
      actions: [
        if (showHome && showBack && !compact)
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: onHome ?? () => context.go('/'),
            tooltip: 'Home',
          ),
        ...?actions,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(69);
}
