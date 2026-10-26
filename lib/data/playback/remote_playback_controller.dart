import 'dart:async';

/// Scoped to the active player on this device. A stale screen cannot unregister
/// its replacement. Transport authorization remains owned by LanSyncServer.
class RemotePlaybackController {
  Object? _owner;
  Map<String, Object?> Function()? _status;
  Future<void> Function(String, double?)? _perform;
  Future<void> _pending = Future.value();
  Object attach({
    required Map<String, Object?> Function() status,
    required Future<void> Function(String, double?) perform,
  }) {
    final owner = Object();
    _owner = owner;
    _status = status;
    _perform = perform;
    return owner;
  }

  void detach(Object? owner) {
    if (identical(owner, _owner)) {
      _owner = null;
      _status = null;
      _perform = null;
    }
  }

  Map<String, Object?> get status => _status?.call() ?? {'active': false};
  Future<void> execute(String action, double? value, {String? expectedItemId}) {
    const names = {
      'play',
      'pause',
      'seek',
      'rate',
      'volume',
      'mute',
      'next',
      'previous',
      'stop',
      'fullscreen',
      'mini',
      'frame',
      'chapter',
      'audioTrack',
      'subtitleTrack',
      'shuffle',
      'repeat',
    };
    if (!names.contains(action) || (value != null && !value.isFinite)) {
      throw const FormatException('Invalid player command.');
    }
    if ([
          'seek',
          'rate',
          'volume',
          'chapter',
          'audioTrack',
          'subtitleTrack',
        ].contains(action) &&
        value == null) {
      throw const FormatException('A numeric command value is required.');
    }
    if (action == 'seek' && value! < 0 ||
        action == 'rate' && (value! < .25 || value > 4) ||
        action == 'volume' && (value! < 0 || value > 100)) {
      throw const FormatException(
        'The command value is outside the supported range.',
      );
    }
    if ({'chapter', 'audioTrack', 'subtitleTrack'}.contains(action) &&
        (value! != value.roundToDouble() || value < -1 || value > 100000))
      throw const FormatException('Invalid track/chapter identifier');
    if (expectedItemId != null && status['itemId'] != expectedItemId)
      throw StateError('Host title changed. Refresh the remote.');
    final supported = status['commands'];
    if (supported is List && !supported.contains(action))
      throw const FormatException('This player does not support that command');
    final owner = _owner;
    final result = _pending.catchError((Object _) {}).then((_) async {
      if (owner == null ||
          !identical(owner, _owner) ||
          _perform == null ||
          expectedItemId != null && status['itemId'] != expectedItemId) {
        throw StateError('No active player.');
      }
      await _perform!(action, value);
    });
    _pending = result;
    return result;
  }
}
