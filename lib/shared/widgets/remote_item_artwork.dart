import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/reader/reader_jobs.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/catalog/catalog_identity_store.dart';

final _remoteArtworkSelection = StreamProvider.autoDispose
    .family<String?, Item>((ref, item) {
      final db = ref.read(appDatabaseProvider);
      return (db.select(
        db.items,
      )..where((t) => t.id.equals(item.id))).watchSingleOrNull().asyncMap((
        current,
      ) async {
        if (current == null) return null;
        final metadata = await MediaCatalogRepository(db).metadata(current);
        final decision = await CatalogIdentityStore(db).decision(current.id);
        return '${metadata['artworkUrl']}:${decision?['revision'] ?? 0}';
      });
    });

final _artworkJobs = ReaderJobScheduler(
  maxConcurrent: 2,
  maxInflightBytes: 8 * 1024 * 1024,
);
final remoteArtworkBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, Item>((ref, item) async {
      final selection = await ref.watch(_remoteArtworkSelection(item).future);
      if (!ref.mounted) return null;
      final source = await ref.read(lanSyncClientProvider).artworkFor(item);
      if (!ref.mounted) return null;
      final lease = _artworkJobs.request<Uint8List?>(
        key: '${source.uri}:${item.updatedAt}:${item.modifiedAt}:$selection',
        priority: ReaderPriority.thumbnail,
        estimatedBytes: 2 * 1024 * 1024,
        run: (cancel) async {
          final client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 8);
          cancel.onCancel(() => client.close(force: true));
          try {
            final request = await client.getUrl(source.uri);
            request.followRedirects = false;
            source.headers.forEach(request.headers.set);
            final response = await request.close().timeout(
              const Duration(seconds: 12),
            );
            if (response.statusCode != 200) return null;
            final bytes = BytesBuilder(copy: false);
            await for (final chunk in response.timeout(
              const Duration(seconds: 12),
            )) {
              cancel.check();
              if (bytes.length + chunk.length > 2 * 1024 * 1024) return null;
              bytes.add(chunk);
            }
            return bytes.takeBytes();
          } finally {
            client.close(force: true);
          }
        },
      );
      ref.onDispose(lease.release);
      return lease.future;
    });

class RemoteItemArtwork extends ConsumerWidget {
  const RemoteItemArtwork({
    super.key,
    required this.item,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });
  final Item item;
  final Widget placeholder;
  final BoxFit fit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(remoteArtworkBytesProvider(item)).asData?.value;
    return bytes == null
        ? placeholder
        : Image.memory(
            bytes,
            fit: fit,
            cacheWidth: 640,
            errorBuilder: (_, __, ___) => placeholder,
          );
  }
}
