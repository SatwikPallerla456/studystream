import 'dart:async';
import 'dart:collection';

enum ReaderPriority {
  visible,
  analysis,
  adjacent,
  thumbnail,
  geometry,
  background,
}

class ReaderCancelled implements Exception {
  const ReaderCancelled();
}

class ReaderCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>[];
  bool get cancelled => _cancelled;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }

  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void check() {
    if (_cancelled) throw const ReaderCancelled();
  }
}

class ReaderLease<T> {
  ReaderLease(this.future, this.release);
  final Future<T> future;
  final void Function() release;
}

class _Job {
  _Job(this.key, this.priority, this.bytes, this.run, this.disposeResult);
  final String key;
  ReaderPriority priority;
  final int bytes;
  final Future<Object?> Function(ReaderCancellation) run;
  final void Function(Object?)? disposeResult;
  Object? value;
  bool finished = false, cleaned = false;
  final token = ReaderCancellation();
  final result = Completer<Object?>();
  int owners = 0;
  bool started = false;
}

/// Budgets are conservative implementation limits pending the separate measured
/// acceptance phase. Speculative work is disabled until those measurements exist.
class ReaderJobScheduler {
  ReaderJobScheduler({
    this.maxConcurrent = 2,
    this.maxInflightBytes = 128 * 1024 * 1024,
  }) {
    if (maxConcurrent < 1 || maxInflightBytes < 1)
      throw ArgumentError('Reader budgets must be positive');
  }
  final int maxConcurrent, maxInflightBytes;
  final _jobs = <String, _Job>{};
  int _active = 0, _bytes = 0;
  bool _closed = false;
  int get inflightBytes => _bytes;
  ReaderLease<T> request<T>({
    required String key,
    required ReaderPriority priority,
    required int estimatedBytes,
    required Future<T> Function(ReaderCancellation) run,
    void Function(T)? disposeResult,
  }) {
    if (_closed) throw StateError('Reader jobs closed');
    if (estimatedBytes < 0 || estimatedBytes > maxInflightBytes)
      throw StateError('Page exceeds the in-flight allocation budget');
    // A released request can still be unwinding an asynchronous decode. A
    // returning page must start fresh instead of inheriting that cancellation.
    final candidate = _jobs[key];
    final existing = candidate?.token.cancelled == false ? candidate : null;
    final job =
        existing ??
        _Job(
          key,
          priority,
          estimatedBytes,
          (token) => run(token),
          disposeResult == null ? null : (value) => disposeResult(value as T),
        );
    if (existing == null) _jobs[key] = job;
    if (priority.index < job.priority.index) job.priority = priority;
    job.owners++;
    var released = false;
    final future = job.result.future.then((value) => value as T);
    _drain();
    return ReaderLease(future, () {
      if (released) return;
      released = true;
      job.owners--;
      if (job.owners == 0) {
        job.token.cancel();
        if (job.finished) _cleanup(job);
        if (!job.started) {
          if (identical(_jobs[key], job)) _jobs.remove(key);
          if (!job.result.isCompleted)
            job.result.completeError(const ReaderCancelled());
        }
      }
    });
  }

  void _drain() {
    if (_closed) return;
    final waiting =
        _jobs.values
            .where(
              (job) => !job.started && job.owners > 0 && !job.token.cancelled,
            )
            .toList()
          ..sort((a, b) => a.priority.index.compareTo(b.priority.index));
    for (final job in waiting) {
      if (_active >= maxConcurrent) return;
      if (_bytes + job.bytes > maxInflightBytes) continue;
      job.started = true;
      _active++;
      _bytes += job.bytes;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_Job job) async {
    try {
      job.token.check();
      final value = await job.run(job.token);
      job.value = value;
      job.finished = true;
      job.token.check();
      job.result.complete(value);
    } catch (error, stack) {
      job.result.completeError(error, stack);
    } finally {
      job.finished = true;
      if (job.owners == 0 || job.token.cancelled) _cleanup(job);
      _active--;
      _bytes -= job.bytes;
      _drain();
    }
  }

  void _cleanup(_Job job) {
    if (job.cleaned) return;
    job.cleaned = true;
    if (job.value != null) job.disposeResult?.call(job.value);
    if (identical(_jobs[job.key], job)) _jobs.remove(job.key);
  }

  /// Release speculative work on memory pressure without invalidating visible
  /// page leases. In-flight native work remains budgeted until it unwinds.
  void releaseSpeculative() {
    for (final job in _jobs.values.toList()) {
      if (job.priority.index < ReaderPriority.adjacent.index) continue;
      job.token.cancel();
      if (job.finished) _cleanup(job);
      if (!job.started) {
        if (identical(_jobs[job.key], job)) _jobs.remove(job.key);
        if (!job.result.isCompleted)
          job.result.completeError(const ReaderCancelled());
      }
    }
    _drain();
  }

  void dispose() {
    _closed = true;
    for (final job in _jobs.values.toList()) {
      job.token.cancel();
      if (job.finished) _cleanup(job);
      if (!job.started && !job.result.isCompleted)
        job.result.completeError(const ReaderCancelled());
    }
    _jobs.removeWhere((_, job) => !job.started);
  }
}

/// Access-aware retained buffers; durable state is deliberately outside this cache.
class ReaderByteCache<T> {
  ReaderByteCache(this.maxBytes, {this.onEvict});
  final int maxBytes;
  final void Function(T)? onEvict;
  final _entries = LinkedHashMap<String, ({T value, int bytes})>();
  int bytes = 0;
  T? get(String key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;
    return entry.value;
  }

  void put(String key, T value, int size) {
    if (size < 0) throw ArgumentError.value(size, 'size');
    final old = _entries.remove(key);
    if (old != null) {
      bytes -= old.bytes;
      if (!identical(old.value, value)) onEvict?.call(old.value);
    }
    if (size > maxBytes) {
      onEvict?.call(value);
      return;
    }
    while (bytes + size > maxBytes && _entries.isNotEmpty) {
      final entry = _entries.remove(_entries.keys.first)!;
      bytes -= entry.bytes;
      onEvict?.call(entry.value);
    }
    _entries[key] = (value: value, bytes: size);
    bytes += size;
  }

  void clear() {
    for (final entry in _entries.values) {
      onEvict?.call(entry.value);
    }
    _entries.clear();
    bytes = 0;
  }
}
