import 'dart:io';
import 'package:flutter/services.dart';

/// Retains user-selected macOS folders using app-scoped security bookmarks.
class FolderAccess {
  static const _channel = MethodChannel('studystream/folder_access');
  static Future<void> retain(String path) async {
    if (Platform.isMacOS) {
      await _channel.invokeMethod<void>('retain', {'path': path});
    }
  }

  static Future<void> restore() async {
    if (Platform.isMacOS) await _channel.invokeMethod<void>('restore');
  }
}
