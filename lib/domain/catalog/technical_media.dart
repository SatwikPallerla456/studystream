import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/db/app_database.dart';
import 'media_probe.dart';

/// Versioned, path-free technical payload; rates are bits/s, Hz and frames/s.
abstract final class TechnicalMediaContract {
  static const fields = {
    'durationSeconds',
    'pageCount',
    'container',
    'analysisState',
    'analysisError',
    'width',
    'height',
    'codec',
    'bitrate',
    'channels',
    'sampleRate',
    'videoOrientation',
    'streams',
    'chapters',
  };
  static Map<String, dynamic> project(Map<String, dynamic> input) {
    final output = <String, dynamic>{
      for (final key in fields)
        if (input[key] != null) key: input[key],
    };
    void scalar(Map<String, dynamic> row, String key, double max) {
      final value = row[key];
      if (value != null &&
          (value is! num || !value.isFinite || value < 0 || value > max))
        throw FormatException('Invalid technical $key');
    }

    void text(Map<String, dynamic> row, String key, int limit) {
      final value = row[key];
      if (value != null &&
          (value is! String ||
              value.length > limit ||
              (value.startsWith('/') ||
                  value.contains('\\') ||
                  value.contains(RegExp(r'[\x00-\x1f]')))))
        throw FormatException('Invalid technical $key');
    }

    void numbers(Map<String, dynamic> row) {
      for (final key in [
        'width',
        'height',
        'channels',
        'sampleRate',
        'pageCount',
      ])
        scalar(row, key, 1000000);
      scalar(row, 'bitrate', 1000000000000);
      scalar(row, 'durationSeconds', 315576000);
      scalar(row, 'frameRate', 1000);
      scalar(row, 'videoOrientation', 7);
      text(row, 'codec', 256);
      text(row, 'language', 32);
    }

    numbers(output);
    text(output, 'container', 32);
    if (!{
      'indexed',
      'complete',
      'unsupported',
      'failed',
    }.contains(output['analysisState']))
      throw const FormatException('Invalid analysis state');
    if (output['analysisError'] != null &&
        output['analysisError'] != 'parseFailed')
      throw const FormatException('Invalid analysis error');
    final streams = output['streams'];
    if (streams != null) {
      if (streams is! List || streams.length > 128)
        throw const FormatException('Invalid media streams');
      output['streams'] = [
        for (final stream in streams)
          (() {
            if (stream is! Map ||
                !{
                  'video',
                  'audio',
                  'subtitle',
                  'unknown',
                }.contains(stream['kind']) ||
                stream['id'] is! int)
              throw const FormatException('Invalid stream');
            final safe = <String, dynamic>{
              for (final key in [
                'id',
                'kind',
                'codec',
                'language',
                'bitrate',
                'width',
                'height',
                'videoOrientation',
                'frameRate',
                'channels',
                'sampleRate',
              ])
                if (stream[key] != null) key: stream[key],
            };
            numbers(safe);
            return safe;
          })(),
      ];
    }
    if (output['chapters'] case final Object chapters) {
      if (chapters is! List || chapters.length > 512)
        throw const FormatException('Invalid chapter list');
      var previous = -1.0;
      output['chapters'] = [
        for (final chapter in chapters)
          (() {
            if (chapter is! Map ||
                chapter['startSeconds'] is! num ||
                !(chapter['startSeconds'] as num).isFinite ||
                (chapter['startSeconds'] as num) < 0 ||
                (chapter['startSeconds'] as num) < previous ||
                (chapter['startSeconds'] as num) > 315576000)
              throw const FormatException('Invalid chapter time');
            previous = (chapter['startSeconds'] as num).toDouble();
            final title = chapter['title'];
            if (title is! String ||
                title.length > 256 ||
                title.contains(RegExp(r'[\x00-\x1f]')))
              throw const FormatException('Invalid chapter title');
            return {'title': title, 'startSeconds': previous};
          })(),
      ];
    }
    return output;
  }
}

class TechnicalMediaAnalyzer {
  const TechnicalMediaAnalyzer(this.db);
  final AppDatabase db;
  static const version = 3;
  static const _channel = MethodChannel('tangerine/playback');
  static Future<void> _tail = Future.value();
  static bool supports(Item item) =>
      !kIsWeb &&
      {
        'audio',
        'video',
        'image',
        'pdf',
        'epub',
        'cbz',
      }.contains(item.itemType) &&
      !item.filePath.startsWith('remote:');
  Future<Map<String, dynamic>?> read(Item item) async {
    final row = await db
        .customSelect(
          'SELECT payload,content_revision FROM technical_media WHERE item_id=?',
          variables: [Variable(item.id)],
        )
        .getSingleOrNull();
    if (row == null || row.data['content_revision'] != _revision(item))
      return null;
    return TechnicalMediaContract.project(
      Map<String, dynamic>.from(
        jsonDecode(row.data['payload'] as String) as Map,
      ),
    );
  }

  static String _revision(Item item) =>
      item.fingerprint ?? 'legacy:${item.fileSize}:${item.modifiedAt}';
  Future<Map<String, dynamic>> analyze(
    Item item, {
    bool Function()? isCurrent,
  }) {
    final work = _tail.then((_) => _analyze(item, isCurrent: isCurrent));
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return work;
  }

  Future<Map<String, dynamic>> _analyze(
    Item item, {
    bool Function()? isCurrent,
  }) async {
    if (!supports(item))
      throw const FormatException('Analyze this file on its host device.');
    if (isCurrent?.call() == false)
      throw const FormatException('Analysis cancelled');
    final file = File(item.filePath), before = await File(item.filePath).stat();
    if (before.type != FileSystemEntityType.file ||
        (item.fileSize != null && before.size != item.fileSize) ||
        (item.modifiedAt != null &&
            before.modified.millisecondsSinceEpoch != item.modifiedAt))
      throw const FileSystemException(
        'This file changed or is unavailable. Rescan the source first.',
      );
    Map<String, dynamic> payload;
    try {
      final nativeMac =
          defaultTargetPlatform == TargetPlatform.macOS &&
          {'audio', 'video'}.contains(item.itemType) &&
          !{'m4a', 'm4b'}.contains(item.filename.split('.').last.toLowerCase());
      final result = nativeMac
          ? await _channel
                .invokeMapMethod<String, dynamic>('analyzeFile', {
                  'path': file.path,
                })
                .timeout(const Duration(seconds: 8))
          : await MediaProbe.read(item);
      if (result == null)
        throw const FormatException('No technical analysis returned.');
      payload = TechnicalMediaContract.project(result);
    } catch (_) {
      payload = {
        'analysisState': 'failed',
        'analysisError': 'parseFailed',
        'container': item.filename.split('.').last.toLowerCase(),
      };
    }
    final after = await file.stat();
    if (after.type != FileSystemEntityType.file ||
        after.size != before.size ||
        after.modified != before.modified)
      throw const FileSystemException(
        'The file changed during analysis. Rescan and try again.',
      );
    if (isCurrent?.call() == false)
      throw const FormatException('Analysis cancelled');
    await db.transaction(() async {
      final current = await db.getItemById(item.id);
      if (current == null ||
          current.filePath != item.filePath ||
          current.fileSize != item.fileSize ||
          current.modifiedAt != item.modifiedAt ||
          current.unavailable ||
          isCurrent?.call() == false ||
          _revision(current) != _revision(item))
        throw const FormatException(
          'This file changed while analysis was running.',
        );
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT INTO technical_media(id,library_id,item_id,content_revision,analysis_version,payload,updated_at) VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET content_revision=excluded.content_revision,analysis_version=excluded.analysis_version,payload=excluded.payload,updated_at=excluded.updated_at',
        [
          item.id,
          item.libraryId,
          item.id,
          _revision(item),
          version,
          jsonEncode(payload),
          now,
        ],
      );
      final duration = payload['durationSeconds'], pages = payload['pageCount'];
      if ((duration is num && duration > 0) || (pages is num && pages > 0))
        await (db.update(db.items)..where((i) => i.id.equals(item.id))).write(
          ItemsCompanion(
            durationSeconds: duration is num && duration > 0
                ? Value(duration.toDouble())
                : const Value.absent(),
            pageCount: pages is num && pages > 0
                ? Value(pages.toInt())
                : const Value.absent(),
            version: Value(current.version + 1),
            updatedAt: Value(
              now > current.updatedAt ? now : current.updatedAt + 1,
            ),
          ),
        );
    });
    return payload;
  }
}
