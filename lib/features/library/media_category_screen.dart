import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../shared/widgets/study_ui.dart';
import '../../shared/widgets/media_categories.dart';
import '../media/media_browser_section.dart';
import 'library_creation.dart';
import 'library_scan_dialog.dart';
import 'category_browse_section.dart';
import 'library_processing_screen.dart';

class MediaCategoryScreen extends ConsumerWidget {
  const MediaCategoryScreen({super.key, required this.kind});
  final LibraryKind kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppTopBar(
        title: kind.label,
        showBack: true,
        actions: [
          TextButton.icon(
            onPressed: () => createMediaLibrary(context, kind: kind),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Add library'),
          ),
        ],
      ),
      body: StudyPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder(
              stream: db
                  .customSelect(
                    "SELECT DISTINCT l.id,l.title FROM libraries l JOIN items i ON i.library_id=l.id JOIN catalog_facets f ON f.item_id=i.id AND f.field='category' WHERE f.value=? ORDER BY l.title,l.id LIMIT 100",
                    variables: [drift.Variable(kind.name)],
                    readsFrom: {db.items, db.libraries},
                  )
                  .watch(),
              builder: (context, snapshot) {
                final sources = snapshot.data ?? [];
                if (sources.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Source libraries'),
                      for (final source in sources)
                        ActionChip(
                          avatar: const Icon(Icons.folder_outlined, size: 18),
                          label: Text(source.data['title'] as String),
                          onPressed: () => context.push(
                            '/library/${Uri.encodeComponent(source.data['id'] as String)}',
                          ),
                        ),
                      if (sources.length == 1) ...[
                        LibraryProcessingButton(
                          libraryId: sources.single.data['id'] as String,
                        ),
                        OutlinedButton.icon(
                          onPressed: () => showLibraryScan(
                            context,
                            libraryId: sources.single.data['id'] as String,
                          ),
                          icon: const Icon(Icons.sync),
                          label: const Text('Scan library'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/library/${Uri.encodeComponent(sources.single.data['id'] as String)}/identify',
                          ),
                          icon: const Icon(Icons.manage_search),
                          label: const Text('Identify titles'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (hasCategoryHierarchy(kind))
              CategoryBrowseSection(
                kind: kind,
                emptyAction: FilledButton.icon(
                  onPressed: () => createMediaLibrary(context, kind: kind),
                  icon: const Icon(Icons.add),
                  label: Text('Add ${kind.label.toLowerCase()} library'),
                ),
              )
            else
              MediaBrowserSection(
                initialKind: kind.name,
                lockCategory: true,
                emptyIcon: mediaCategoryIcon(kind),
                emptyAction: FilledButton.icon(
                  onPressed: () => createMediaLibrary(context, kind: kind),
                  icon: const Icon(Icons.add),
                  label: Text('Add ${kind.label.toLowerCase()} library'),
                ),
                onOpenItem: (item) => context.push(MediaVisuals.route(item)),
              ),
          ],
        ),
      ),
    );
  }
}
