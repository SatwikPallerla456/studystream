import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/services/catalog_artwork_cache.dart';
import '../../domain/reader/reader_jobs.dart' show ReaderLease;

class CatalogCandidateArtwork extends StatefulWidget {
  const CatalogCandidateArtwork({
    super.key,
    required this.url,
    this.width = 64,
    this.height = 96,
    this.allowRetry = false,
  });
  final String? url;
  final double width, height;
  final bool allowRetry;
  @override
  State<CatalogCandidateArtwork> createState() =>
      _CatalogCandidateArtworkState();
}

class _CatalogCandidateArtworkState extends State<CatalogCandidateArtwork> {
  late ReaderLease<String?> _lease = CatalogArtworkCache.instance.acquire(
    widget.url,
  );
  bool _refreshing = false;
  @override
  void didUpdateWidget(CatalogCandidateArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _lease.release();
      _lease = CatalogArtworkCache.instance.acquire(widget.url);
    }
  }

  @override
  void dispose() {
    _lease.release();
    super.dispose();
  }

  Future<void> _retry() async {
    final url = widget.url;
    if (url == null || _refreshing) return;
    setState(() => _refreshing = true);
    _lease.release();
    try {
      await CatalogArtworkCache.instance.refresh(url);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _lease = CatalogArtworkCache.instance.acquire(widget.url);
      _refreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<String?>(
        future: _lease.future,
        builder: (context, snapshot) {
          if (snapshot.data case final String path) {
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 600,
              errorBuilder: (_, _, _) => _placeholder(),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              _placeholder(),
              if (widget.allowRetry &&
                  !_refreshing &&
                  snapshot.connectionState == ConnectionState.done)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IconButton(
                    tooltip: 'Retry artwork',
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
  Widget _placeholder() => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(Icons.image_outlined)),
  );
}
