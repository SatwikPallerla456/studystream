import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/services/catalog_artwork_cache.dart';

class CatalogCandidateArtwork extends StatefulWidget {
  const CatalogCandidateArtwork({
    super.key,
    required this.url,
    this.width = 64,
    this.height = 96,
  });
  final String? url;
  final double width, height;
  @override
  State<CatalogCandidateArtwork> createState() =>
      _CatalogCandidateArtworkState();
}

class _CatalogCandidateArtworkState extends State<CatalogCandidateArtwork> {
  late Future<String?> _image = CatalogArtworkCache.instance.get(widget.url);
  @override
  void didUpdateWidget(CatalogCandidateArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url)
      _image = CatalogArtworkCache.instance.get(widget.url);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<String?>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.data case final String path) {
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 600,
              errorBuilder: (_, _, _) => _placeholder(),
            );
          }
          return _placeholder();
        },
      ),
    ),
  );
  Widget _placeholder() => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(Icons.image_outlined)),
  );
}
