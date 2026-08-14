import 'dart:async';

import 'package:drift/drift.dart' as drift;

import '../../data/db/app_database.dart';
import 'resume_service.dart';

class MediaProgressWriter {
  MediaProgressWriter({
    required this.database,
    required this.item,
    this.deviceId = 'local',
    this.saveInterval = const Duration(seconds: 5),
    this.completionThreshold = 0.90,
    this.resumeRewindSeconds = 10,
  });

  final AppDatabase database;
  final Item item;
  final String deviceId;
  final Duration saveInterval;
  final double completionThreshold;
  final double resumeRewindSeconds;

  Timer? _timer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1;
  bool _hasSnapshot = false;
  bool _disposing = false;
  bool _disposed = false;
  Future<void>? _activeWrite;

  void seed({
    required Duration position,
    required Duration duration,
    required double speed,
  }) {
    if (_disposed || _disposing) return;
    _position = position;
    _duration = duration;
    _speed = speed;
    _hasSnapshot = true;
  }

  void schedule({
    required Duration position,
    required Duration duration,
    required double speed,
  }) {
    if (_disposed || _disposing) return;
    _position = position;
    _duration = duration;
    _speed = speed;
    _hasSnapshot = true;
    _timer ??= Timer(saveInterval, () {
      _timer = null;
      unawaited(flush());
    });
  }

  Future<void> flush({bool forceComplete = false}) async {
    if (_disposed && _activeWrite == null) return;
    _timer?.cancel();
    _timer = null;
    if (_activeWrite != null) await _activeWrite;
    if (!_hasSnapshot) return;
    final write = _persist(forceComplete: forceComplete);
    _activeWrite = write;
    try {
      await write;
    } finally {
      if (identical(_activeWrite, write)) _activeWrite = null;
    }
  }

  Future<void> _persist({required bool forceComplete}) async {
    final old = await database.getPlaybackByItemId(item.id);
    final position = _position.inMilliseconds / 1000;
    final duration = _duration.inMilliseconds / 1000;
    final automatic = ResumeService.mediaCompleted(
      positionSeconds: position,
      durationSeconds: duration,
      threshold: completionThreshold,
    );
    final completed = old?.manualCompletion ?? (forceComplete || automatic);
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.upsertPlayback(
      PlaybackProgressCompanion(
        itemId: drift.Value(item.id),
        lastPositionSeconds: drift.Value(position),
        resumePositionSeconds: drift.Value(
          ResumeService.mediaResumeSeconds(
            position,
            durationSeconds: duration,
            completed: completed,
            rewindSeconds: resumeRewindSeconds,
          ),
        ),
        durationSeconds: drift.Value(duration),
        percentWatched: drift.Value(
          completed
              ? 100
              : ResumeService.mediaPercent(
                  positionSeconds: position,
                  durationSeconds: duration,
                ),
        ),
        completed: drift.Value(completed),
        manualCompletion: old?.manualCompletion == null
            ? const drift.Value.absent()
            : drift.Value(old!.manualCompletion),
        playbackSpeed: drift.Value(_speed),
        lastOpenedAt: drift.Value(now),
        lastEventAt: drift.Value(now),
        deviceId: drift.Value(deviceId),
        version: drift.Value((old?.version ?? 0) + 1),
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed || _disposing) return;
    _disposing = true;
    _timer?.cancel();
    _timer = null;
    await flush();
    _disposed = true;
    _disposing = false;
  }
}

class ReadingProgressWriter {
  ReadingProgressWriter({
    required this.database,
    required this.item,
    this.deviceId = 'local',
    this.completionThreshold = 0.90,
  });

  final AppDatabase database;
  final Item item;
  final String deviceId;
  final double completionThreshold;

  int currentPage = 1;
  int totalPages = 0;
  int pagesVisited = 1;
  double scrollOffset = 0;
  double zoom = 1;
  String readingMode = 'fitWidth';
  bool _disposed = false;

  Future<void> save({bool forceComplete = false}) async {
    if (_disposed) return;
    final old = await database.getReadingByItemId(item.id);
    final automatic = ResumeService.readingCompleted(
      currentPage: currentPage,
      totalPages: totalPages,
      pagesVisited: pagesVisited,
      threshold: completionThreshold,
    );
    final completed = old?.manualCompletion ?? (forceComplete || automatic);
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.upsertReading(
      ReadingProgressCompanion(
        itemId: drift.Value(item.id),
        lastPage: drift.Value(currentPage),
        lastScrollOffset: drift.Value(scrollOffset),
        resumePage: drift.Value(currentPage),
        resumeScrollOffset: drift.Value(scrollOffset),
        percentRead: drift.Value(
          completed
              ? 100
              : ResumeService.readingPercent(
                  currentPage: currentPage,
                  totalPages: totalPages,
                ),
        ),
        completed: drift.Value(completed),
        manualCompletion: old?.manualCompletion == null
            ? const drift.Value.absent()
            : drift.Value(old!.manualCompletion),
        zoom: drift.Value(zoom),
        readingMode: drift.Value(readingMode),
        lastOpenedAt: drift.Value(now),
        lastEventAt: drift.Value(now),
        deviceId: drift.Value(deviceId),
        version: drift.Value((old?.version ?? 0) + 1),
      ),
    );
  }

  Future<void> dispose() async {
    await save();
    _disposed = true;
  }
}
