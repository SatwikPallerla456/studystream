final _leadingNumber = RegExp(r'^\s*(\d+)');

int extractLeadingNumber(String value) {
  final match = _leadingNumber.firstMatch(value);
  if (match == null) return 1 << 30;
  return int.tryParse(match.group(1)!) ?? (1 << 30);
}

int naturalCourseCompare(String a, String b) {
  final aNum = extractLeadingNumber(a);
  final bNum = extractLeadingNumber(b);

  if (aNum != bNum) {
    return aNum.compareTo(bNum);
  }

  return a.toLowerCase().compareTo(b.toLowerCase());
}
