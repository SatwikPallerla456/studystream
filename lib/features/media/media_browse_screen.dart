import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../shared/widgets/study_ui.dart';
import 'media_browser_section.dart';

class MediaBrowseScreen extends StatelessWidget {
  const MediaBrowseScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: 'All media', showBack: true),
    body: StudyPage(
      key: const PageStorageKey('all-media'),
      child: MediaBrowserSection(
        onOpenItem: (item) => context.push(MediaVisuals.route(item)),
      ),
    ),
  );
}
