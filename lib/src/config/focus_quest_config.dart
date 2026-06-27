enum BackgroundBehavior { pause, cancel, keepRunning }

/// Configures how focus sessions reward progress and handle lifecycle interruptions.
class FocusQuestConfig {
  const FocusQuestConfig({
    this.defaultSessionDuration = const Duration(minutes: 25),
    this.pointsPerFocusedMinute = 1,
    this.completionBonus = 10,
    this.dailyGoalDuration = const Duration(minutes: 120),
    this.maxInterruptions = 3,
    this.backgroundBehavior = BackgroundBehavior.pause,
    this.partialRewardEnabled = true,
    this.levelBaseXp = 100,
    this.levelExponent = 1.2,
    this.streakMinimumDailyTargetMinutes = 25,
    this.partialRewardMultiplier = 0.5,
  });

  final Duration defaultSessionDuration;
  final int pointsPerFocusedMinute;
  final int completionBonus;
  final Duration dailyGoalDuration;
  final int maxInterruptions;
  final BackgroundBehavior backgroundBehavior;
  final bool partialRewardEnabled;
  final int levelBaseXp;
  final double levelExponent;
  final int streakMinimumDailyTargetMinutes;
  final double partialRewardMultiplier;

  FocusQuestConfig copyWith({
    Duration? defaultSessionDuration,
    int? pointsPerFocusedMinute,
    int? completionBonus,
    Duration? dailyGoalDuration,
    int? maxInterruptions,
    BackgroundBehavior? backgroundBehavior,
    bool? partialRewardEnabled,
    int? levelBaseXp,
    double? levelExponent,
    int? streakMinimumDailyTargetMinutes,
    double? partialRewardMultiplier,
  }) {
    return FocusQuestConfig(
      defaultSessionDuration:
          defaultSessionDuration ?? this.defaultSessionDuration,
      pointsPerFocusedMinute:
          pointsPerFocusedMinute ?? this.pointsPerFocusedMinute,
      completionBonus: completionBonus ?? this.completionBonus,
      dailyGoalDuration: dailyGoalDuration ?? this.dailyGoalDuration,
      maxInterruptions: maxInterruptions ?? this.maxInterruptions,
      backgroundBehavior: backgroundBehavior ?? this.backgroundBehavior,
      partialRewardEnabled: partialRewardEnabled ?? this.partialRewardEnabled,
      levelBaseXp: levelBaseXp ?? this.levelBaseXp,
      levelExponent: levelExponent ?? this.levelExponent,
      streakMinimumDailyTargetMinutes:
          streakMinimumDailyTargetMinutes ??
          this.streakMinimumDailyTargetMinutes,
      partialRewardMultiplier:
          partialRewardMultiplier ?? this.partialRewardMultiplier,
    );
  }
}
