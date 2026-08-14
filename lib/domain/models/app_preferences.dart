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
