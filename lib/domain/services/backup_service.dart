import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../data/db/app_database.dart';

class BackupService {
  const BackupService(this.database);

  final AppDatabase database;

  Future<String?> exportBackup() async {
    final snapshot = await database.exportData();
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(snapshot)),
    );
    final path = await FilePicker.platform.saveFile(
      bytes: bytes,
      dialogTitle: 'Export Tangerine backup',
      fileName: 'tangerine-backup-${_dateStamp()}.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return null;
    if (Platform.isAndroid || Platform.isIOS) return path;
    final target = path.toLowerCase().endsWith('.json') ? path : '$path.json';
    await File(target).writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
      flush: true,
    );
    return target;
  }

  Future<String?> importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Restore Tangerine backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return null;
    final file = File(path);
    if (await file.length() > 64 * 1024 * 1024) {
      throw const FormatException(
        'This backup is too large to restore safely.',
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('This is not a valid Tangerine backup.');
    }
    await database.importData(decoded);
    return path;
  }

  String _dateStamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }
}
