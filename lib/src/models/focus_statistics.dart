/// Calculated focus statistics for the current profile and history.
class FocusStatistics {
  /// Creates a statistics snapshot.
  const FocusStatistics({
    this.focusedToday = Duration.zero,
    this.focusedThisWeek = Duration.zero,
    this.focusedThisMonth = Duration.zero,
    this.totalFocused = Duration.zero,
    this.completedSessions = 0,
    this.cancelledSessions = 0,
    this.completionRate = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPoints = 0,
    this.totalExperience = 0,
    this.currentLevel = 1,
    this.progressToNextLevel = 0,
  });

  /// Focused duration completed today.
  final Duration focusedToday;

  /// Focused duration completed in the current week.
  final Duration focusedThisWeek;

  /// Focused duration completed in the current month.
  final Duration focusedThisMonth;

  /// Total focused duration across all finalized sessions.
  final Duration totalFocused;

  /// Number of completed sessions.
  final int completedSessions;

  /// Number of cancelled sessions.
  final int cancelledSessions;

  /// Percentage of finalized sessions that were completed.
  final double completionRate;

  /// Current qualifying focus-day streak.
  final int currentStreak;

  /// Longest qualifying focus-day streak.
  final int longestStreak;

  /// Total points earned.
  final int totalPoints;

  /// Total experience earned.
  final int totalExperience;

  /// Current level derived from experience.
  final int currentLevel;

  /// Experience progress within the current level band.
  final int progressToNextLevel;
}
