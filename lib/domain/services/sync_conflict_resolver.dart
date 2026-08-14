class SyncConflictResolver {
  const SyncConflictResolver._();

  static Map<String, dynamic> mergeProgress(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localManual = local['manualCompletion'] as bool?;
    final remoteManual = remote['manualCompletion'] as bool?;
    final localEvent = (local['lastEventAt'] as num?)?.toInt() ?? 0;
    final remoteEvent = (remote['lastEventAt'] as num?)?.toInt() ?? 0;

    if (localManual != null || remoteManual != null) {
      if (localManual != null && remoteManual == null) return Map.of(local);
      if (remoteManual != null && localManual == null) return Map.of(remote);
      return _newest(local, remote, localEvent, remoteEvent);
    }

    final localCompleted = local['completed'] == true;
    final remoteCompleted = remote['completed'] == true;
    if (localCompleted != remoteCompleted) {
      return Map.of(localCompleted ? local : remote);
    }

    final localPercent = _progressPercent(local);
    final remotePercent = _progressPercent(remote);
    if (localPercent != remotePercent) {
      return Map.of(localPercent > remotePercent ? local : remote);
    }
    return _newest(local, remote, localEvent, remoteEvent);
  }

  static Map<String, dynamic> mergeMetadata(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localUpdated = (local['updatedAt'] as num?)?.toInt() ?? 0;
    final remoteUpdated = (remote['updatedAt'] as num?)?.toInt() ?? 0;
    return _newest(local, remote, localUpdated, remoteUpdated);
  }

  static List<Map<String, dynamic>> preserveUserContentConflict(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    if (local['content'] == remote['content'] &&
        local['title'] == remote['title'] &&
        local['description'] == remote['description']) {
      return [mergeMetadata(local, remote)];
    }
    final winner = mergeMetadata(local, remote);
    final winnerIsLocal =
        winner['updatedAt'] == local['updatedAt'] &&
        winner['version'] == local['version'] &&
        (winner['deviceId'] ?? '') == (local['deviceId'] ?? '');
    final loser = winnerIsLocal ? remote : local;
    final conflict = Map<String, dynamic>.of(loser);
    conflict['id'] =
        '${loser['id']}-conflict-${loser['deviceId'] ?? 'device'}-${loser['version'] ?? 1}';
    return [winner, conflict];
  }

  static Map<String, dynamic> _newest(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    int localTimestamp,
    int remoteTimestamp,
  ) {
    if (localTimestamp != remoteTimestamp) {
      return Map.of(localTimestamp > remoteTimestamp ? local : remote);
    }
    final localVersion = (local['version'] as num?)?.toInt() ?? 0;
    final remoteVersion = (remote['version'] as num?)?.toInt() ?? 0;
    if (localVersion != remoteVersion) {
      return Map.of(localVersion > remoteVersion ? local : remote);
    }
    final localDevice = (local['deviceId'] ?? local['updatedByDevice'] ?? '')
        .toString();
    final remoteDevice = (remote['deviceId'] ?? remote['updatedByDevice'] ?? '')
        .toString();
    return Map.of(localDevice.compareTo(remoteDevice) >= 0 ? local : remote);
  }

  static double _progressPercent(Map<String, dynamic> value) =>
      ((value['percentWatched'] ?? value['percentRead'] ?? 0) as num)
          .toDouble();
}
