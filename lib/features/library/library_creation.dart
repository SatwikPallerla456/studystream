import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/platform/folder_access.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import 'library_setup_sheet.dart';
import 'library_scan_dialog.dart';

Future<void> createMediaLibrary(
  BuildContext context, {
  LibraryKind? kind,
}) async {
  final setup = await showLibrarySetup(
    context,
    kind?.label ?? 'Movies',
    initialKind: kind ?? LibraryKind.movies,
  );
  if (setup == null || !context.mounted) return;
  if (Platform.isAndroid || Platform.isIOS) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Create a hosted library on your Mac, or add individual files from Home.',
        ),
      ),
    );
    return;
  }
  final path = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Choose a folder for ${setup.name}',
  );
  if (path == null || path.isEmpty || !context.mounted) return;
  try {
    await FolderAccess.retain(path);
    if (!context.mounted) return;
    final id = await showLibraryScan(
      context,
      root: path,
      name: setup.name,
      kind: setup.kind,
    );
    if (context.mounted && id != null)
      context.push('/library/${Uri.encodeComponent(id)}');
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The source folder could not be opened. Check its access and try again.',
          ),
        ),
      );
  }
}
