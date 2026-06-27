/// Controls how a session behaves when the app moves to the background.
enum BackgroundBehavior { pause, cancel, keepRunning }

/// Configures how focus sessions reward progress and handle lifecycle interruptions.
class FocusQuestConfig {
  /// Creates a focus engine configuration.
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

  /// Duration used when [FocusQuestController.start] receives no duration.
  final Duration defaultSessionDuration;

  /// Base points awarded for each focused minute.
  final int pointsPerFocusedMinute;

  /// Extra points and experience awarded for completed sessions.
  final int completionBonus;

  /// Daily focused duration target used for progress calculations.
  final Duration dailyGoalDuration;

  /// Number of lifecycle interruptions allowed before a session fails.
  final int maxInterruptions;

  /// Policy applied when the app moves to the background.
  final BackgroundBehavior backgroundBehavior;

  /// Whether cancelled sessions can earn partial rewards.
  final bool partialRewardEnabled;

  /// Base XP value used by the default level calculation.
  final int levelBaseXp;

  /// Exponent used by the default level calculation.
  final double levelExponent;

  /// Minimum focused minutes needed for a day to count toward streaks.
  final int streakMinimumDailyTargetMinutes;

  /// Multiplier applied to partial rewards from cancelled sessions.
  final double partialRewardMultiplier;

  /// Returns a copy with selected configuration values replaced.
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
