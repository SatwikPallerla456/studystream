String cleanDisplayTitle(String value) {
  var text = value;

  text = text.replaceAll('_', ' ');
  text = text.replaceAll('-', ' ');

  text = text.replaceAllMapped(RegExp(r'^\s*\d+\s+'), (_) => '');

  text = text.replaceAllMapped(RegExp(r'^\s*\d+[\._-]+'), (_) => '');

  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  return text;
}
