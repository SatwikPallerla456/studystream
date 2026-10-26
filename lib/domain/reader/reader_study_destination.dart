import 'dart:convert';
import 'package:drift/drift.dart';
import '../../data/db/app_database.dart';
import 'reader_contract.dart';

class ReaderStudyDestination {
  const ReaderStudyDestination(this.locator, this.passage);
  final ReaderLocator? locator;
  final ReaderTextAnchor? passage;
  static Future<ReaderStudyDestination?> load(
    AppDatabase db,
    Item item,
    String? id,
  ) async {
    if (id == null ||
        id.length > 1024 ||
        !RegExp(r'^(note|bookmark):').hasMatch(id))
      return null;
    final row = await db
        .customSelect(
          'SELECT payload FROM study_anchors WHERE id=? AND library_id=? AND item_id=?',
          variables: [
            Variable(id),
            Variable(item.libraryId),
            Variable(item.id),
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    try {
      final payload = jsonDecode(row.data['payload'] as String);
      if (payload is! Map) return null;
      return ReaderStudyDestination(
        ReaderLocator.decode(payload['locator'] as String?),
        ReaderTextAnchor.decode(payload['textRange']),
      );
    } on Object {
      return null;
    }
  }
}
