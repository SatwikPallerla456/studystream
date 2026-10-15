import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;

import '../../data/db/app_database.dart';
import 'resume_service.dart';

/// Serializes immutable snapshots so an older asynchronous save cannot win.
class MediaProgressWriter {
  MediaProgressWriter({
    required this.database,
    required this.item,
    this.deviceId,
    this.saveInterval = const Duration(seconds: 5),
    this.completionThreshold = .90,
    this.resumeRewindSeconds = 10,
    this.onError,
  });

  final AppDatabase database;
  final Item item;
  final String? deviceId;
  final Duration saveInterval;
  final double completionThreshold;
  final double resumeRewindSeconds;
  final void Function(Object error)? onError;
  Timer? _timer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1;
  int _revision = 0;
  int _savedRevision = 0;
  bool _disposing = false;
  bool _disposed = false;
  Future<void> _queue = Future.value();
  Future<void>? _disposal;

  void seed({
    required Duration position,
    required Duration duration,
    required double speed,
  }) {
    if (_disposed || _disposing) return;
    if (position == _position &&
        duration == _duration &&
        speed == _speed &&
        _revision > 0) {
      return;
    }
    _position = position;
    _duration = duration;
    _speed = speed;
    _revision++;
  }

  void schedule({
    required Duration position,
    required Duration duration,
    required double speed,
  }) {
    seed(position: position, duration: duration, speed: speed);
    if (_disposed || _disposing) return;
    _timer ??= Timer(saveInterval, () {
      _timer = null;
      unawaited(
        flush().catchError((Object error) {
          onError?.call(error);
        }),
      );
    });
  }

  Future<void> flush({bool forceComplete = false}) {
    _timer?.cancel();
    _timer = null;
    if (_disposed) return _queue;
    final revision = _revision;
    final position = math.max(0.0, _position.inMilliseconds / 1000);
    final duration = math.max(0.0, _duration.inMilliseconds / 1000);
    final speed = _speed;
    final write = _queue.then((_) async {
      if (revision <= _savedRevision && !forceComplete) return;
      if (revision == 0) return;
      await database.transaction(() async {
        final old = await database.getPlaybackByItemId(item.id);
        final completed =
            old?.manualCompletion ??
            (old?.completed == true ||
                forceComplete ||
                ResumeService.mediaCompleted(
                  positionSeconds: position,
                  durationSeconds: duration,
                  threshold: completionThreshold,
                ));
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
            durationSeconds: drift.Value(
              duration > 0 ? duration : old?.durationSeconds ?? 0,
            ),
            percentWatched: drift.Value(
              completed
                  ? 100
                  : math.max(
                      old?.percentWatched ?? 0,
                      ResumeService.mediaPercent(
                        positionSeconds: position,
                        durationSeconds: duration,
                      ),
                    ),
            ),
            completed: drift.Value(completed),
            manualCompletion: drift.Value(old?.manualCompletion),
            playbackSpeed: drift.Value(speed),
            lastOpenedAt: drift.Value(now),
            lastEventAt: drift.Value(now),
            deviceId: drift.Value(deviceId ?? await database.getDeviceId()),
            version: drift.Value((old?.version ?? 0) + 1),
          ),
        );
      });
      _savedRevision = revision;
    });
    _queue = write.catchError((Object _) {});
    return write;
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _disposing = true;
    try {
      await flush();
    } finally {
      _disposed = true;
    }
  }
}

class ReadingProgressWriter {
  ReadingProgressWriter({
    required this.database,
    required this.item,
    this.deviceId,
    this.completionThreshold = .90,
  });
  final AppDatabase database;
  final Item item;
  final String? deviceId;
  final double completionThreshold;
  int currentPage = 1;
  int totalPages = 0;
  int pagesVisited = 1;
  double scrollOffset = 0;
  double zoom = 1;
  String readingMode = 'fitWidth';
  bool _disposed = false;
  Future<void> _queue = Future.value();
  Future<void>? _disposal;
  Object? _lastSaved;

  Future<void> save({bool forceComplete = false}) {
    if (_disposed || (totalPages <= 0 && !forceComplete)) return _queue;
    final snapshot = (
      currentPage,
      totalPages,
      pagesVisited,
      scrollOffset,
      zoom,
      readingMode,
    );
    final write = _queue.then((_) async {
      if (_lastSaved == snapshot && !forceComplete) return;
      await database.transaction(() async {
        final old = await database.getReadingByItemId(item.id);
        final completed =
            old?.manualCompletion ??
            (old?.completed == true ||
                forceComplete ||
                ResumeService.readingCompleted(
                  currentPage: snapshot.$1,
                  totalPages: snapshot.$2,
                  pagesVisited: snapshot.$3,
                  threshold: completionThreshold,
                ));
        final now = DateTime.now().millisecondsSinceEpoch;
        await database.upsertReading(
          ReadingProgressCompanion(
            itemId: drift.Value(item.id),
            lastPage: drift.Value(snapshot.$1),
            lastScrollOffset: drift.Value(snapshot.$4),
            resumePage: drift.Value(snapshot.$1),
            resumeScrollOffset: drift.Value(snapshot.$4),
            percentRead: drift.Value(
              completed
                  ? 100
                  : math.max(
                      old?.percentRead ?? 0,
                      ResumeService.readingPercent(
                        currentPage: snapshot.$1,
                        totalPages: snapshot.$2,
                      ),
                    ),
            ),
            completed: drift.Value(completed),
            manualCompletion: drift.Value(old?.manualCompletion),
            zoom: drift.Value(snapshot.$5),
            readingMode: drift.Value(snapshot.$6),
            lastOpenedAt: drift.Value(now),
            lastEventAt: drift.Value(now),
            deviceId: drift.Value(deviceId ?? await database.getDeviceId()),
            version: drift.Value((old?.version ?? 0) + 1),
          ),
        );
      });
      _lastSaved = snapshot;
    });
    _queue = write.catchError((Object _) {});
    return write;
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    final write = save();
    _disposed = true;
    await write;
  }
}
