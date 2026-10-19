const playbackSpeeds = [
  0.25,
  0.5,
  0.75,
  1.0,
  1.25,
  1.5,
  1.75,
  2.0,
  2.5,
  3.0,
  4.0,
];

class AppPreferences {
  const AppPreferences({
    this.defaultPlaybackSpeed = 1,
    this.resumeRewindSeconds = 10,
    this.autoAdvance = true,
    this.completionThreshold = 0.90,
  });

  final double defaultPlaybackSpeed;
  final double resumeRewindSeconds;
  final bool autoAdvance;
  final double completionThreshold;

  AppPreferences copyWith({
    double? defaultPlaybackSpeed,
    double? resumeRewindSeconds,
    bool? autoAdvance,
    double? completionThreshold,
  }) {
    return AppPreferences(
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      resumeRewindSeconds: resumeRewindSeconds ?? this.resumeRewindSeconds,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      completionThreshold: completionThreshold ?? this.completionThreshold,
    );
  }
}
