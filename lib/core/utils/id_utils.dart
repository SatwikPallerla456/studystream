import 'dart:convert';
import 'package:crypto/crypto.dart';

String stableId(String input) {
  return sha1.convert(utf8.encode(input)).toString();
}
