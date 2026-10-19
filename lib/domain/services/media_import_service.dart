import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/supported_extensions.dart';
import '../../data/indexer/library_indexer.dart';

/// Copies picker grants/cache files into durable app storage before indexing.
/// This also gives mobile servers a local root they can safely serve.
class MediaImportService {
  const MediaImportService(this.indexer, {this.directory});

  final LibraryIndexer indexer;
  final Directory? directory;
  static Future<void> _imports = Future.value();

  Future<ScanResult?> pickFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Add media to Tangerine',
      type: FileType.custom,
      allowedExtensions: [
        ...videoExtensions,
        ...audioExtensions,
        ...pdfExtensions,
        ...textExtensions,
        ...htmlExtensions,
        ...imageExtensions,
        ...linkExtensions,
        ...docExtensions,
        ...pptExtensions,
        ...epubExtensions,
      ],
      allowMultiple: true,
      withData: false,
      withReadStream: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    return importFiles(picked.files);
  }

  Future<ScanResult> importFiles(List<PlatformFile> files) {
    final imported = _imports.then((_) => _importFiles(files));
    _imports = imported.then<void>((_) {}, onError: (Object _) {});
    return imported;
  }

  Future<ScanResult> _importFiles(List<PlatformFile> files) async {
    final root =
        directory ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'Imported media',
          ),
        );
    await root.create(recursive: true);
    for (final file in files) {
      final name = p.basename(file.name);
      if (name.isEmpty ||
          name == '.' ||
          name == '..' ||
          !isSupportedImportFile(name)) {
        throw FormatException('Unsupported media file: $name');
      }
      var destination = File(p.join(root.path, name));
      var suffix = 2;
      while (await destination.exists()) {
        destination = File(
          p.join(
            root.path,
            '${p.basenameWithoutExtension(name)} (${suffix++})${p.extension(name)}',
          ),
        );
      }
      final temporary = File(p.join(root.path, '.import-${const Uuid().v4()}'));
      try {
        final stream =
            file.readStream ??
            (file.path == null ? null : File(file.path!).openRead());
        if (stream != null) {
          final output = temporary.openWrite();
          try {
            await output.addStream(stream);
          } finally {
            await output.close();
          }
        } else if (file.bytes != null) {
          await temporary.writeAsBytes(file.bytes!, flush: true);
        } else {
          throw FileSystemException(
            'The selected file is no longer accessible',
            name,
          );
        }
        if (await temporary.length() != file.size) {
          throw FileSystemException(
            'The selected file was not copied completely',
            name,
          );
        }
        await temporary.rename(destination.path);
      } catch (_) {
        if (await temporary.exists()) await temporary.delete();
        rethrow;
      }
    }
    return indexer.scanRootFolder(
      rootFolderPath: root.path,
      title: 'Imported media',
    );
  }
}
