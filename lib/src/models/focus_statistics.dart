class FocusStatistics {
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

  final Duration focusedToday;
  final Duration focusedThisWeek;
  final Duration focusedThisMonth;
  final Duration totalFocused;
  final int completedSessions;
  final int cancelledSessions;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;
  final int totalPoints;
  final int totalExperience;
  final int currentLevel;
  final int progressToNextLevel;
}
