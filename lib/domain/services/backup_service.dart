import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../data/db/app_database.dart';

class BackupService {
  const BackupService(this.database);

  final AppDatabase database;

  Future<String?> exportBackup() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export StudyStream backup',
      fileName: 'studystream-backup-${_dateStamp()}.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return null;
    final snapshot = await database.exportData();
    final target = path.toLowerCase().endsWith('.json') ? path : '$path.json';
    await File(target).writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
      flush: true,
    );
    return target;
  }

  Future<String?> importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Restore StudyStream backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return null;
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('This is not a valid StudyStream backup.');
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
