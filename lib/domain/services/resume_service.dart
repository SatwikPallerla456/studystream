class ResumeService {
  const ResumeService._();

  static double mediaResumeSeconds(
    double lastPositionSeconds, {
    double durationSeconds = 0,
    bool completed = false,
    double rewindSeconds = 10,
  }) {
    if (completed) return 0;
    final safePosition = lastPositionSeconds
        .clamp(0, double.infinity)
        .toDouble();
    final endWindow = durationSeconds > 100 ? 5.0 : durationSeconds * .05;
    if (durationSeconds > 0 && safePosition >= durationSeconds - endWindow) {
      return 0;
    }
    if (safePosition <= rewindSeconds + 5) return safePosition;
    return (safePosition - rewindSeconds).clamp(0, double.infinity).toDouble();
  }

  static bool mediaCompleted({
    required double positionSeconds,
    required double durationSeconds,
    double threshold = 0.90,
  }) {
    if (durationSeconds <= 0) return false;
    if (positionSeconds >= durationSeconds - 2) return true;
    return positionSeconds / durationSeconds >= threshold.clamp(0.5, 1.0);
  }

  static double mediaPercent({
    required double positionSeconds,
    required double durationSeconds,
  }) {
    if (durationSeconds <= 0) return 0;
    return (positionSeconds / durationSeconds * 100).clamp(0, 100);
  }

  static bool readingCompleted({
    required int currentPage,
    required int totalPages,
    int pagesVisited = 1,
    double threshold = 0.90,
  }) {
    if (totalPages <= 0 || pagesVisited < 2) return false;
    if (currentPage >= totalPages) return true;
    return currentPage / totalPages >= threshold.clamp(0.5, 1.0);
  }

  static double readingPercent({
    required int currentPage,
    required int totalPages,
  }) {
    if (totalPages <= 0) return 0;
    return (currentPage / totalPages * 100).clamp(0, 100);
  }
}
