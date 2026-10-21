/// Display labels are not filenames: punctuation and leading numbers can be
/// meaningful in a movie, book or album title. File ordering belongs to indexing.
String cleanDisplayTitle(String value) =>
    value.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
