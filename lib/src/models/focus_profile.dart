/// Aggregated user progress across focus sessions.
class FocusProfile {
  /// Creates a profile snapshot.
  const FocusProfile({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPoints = 0,
    this.totalExperience = 0,
    this.completedSessions = 0,
    this.cancelledSessions = 0,
    this.totalFocusedDuration = Duration.zero,
    this.lastCompletedDate,
    this.lastActivityDate,
    this.currentLevel = 1,
  });

  /// Number of qualifying focus days in the current streak.
  final int currentStreak;

  /// Longest qualifying focus-day streak ever reached.
  final int longestStreak;

  /// Total points earned by finalized sessions.
  final int totalPoints;

  /// Total experience earned by finalized sessions.
  final int totalExperience;

  /// Number of completed sessions.
  final int completedSessions;

  /// Number of cancelled or failed sessions counted in the profile.
  final int cancelledSessions;

  /// Total focused duration from finalized sessions.
  final Duration totalFocusedDuration;

  /// Start of the most recent completed focus day.
  final DateTime? lastCompletedDate;

  /// Timestamp of the most recent profile activity.
  final DateTime? lastActivityDate;

  /// Current level derived from total experience.
  final int currentLevel;

  /// Returns a copy with selected profile fields replaced.
  FocusProfile copyWith({
    int? currentStreak,
    int? longestStreak,
    int? totalPoints,
    int? totalExperience,
    int? completedSessions,
    int? cancelledSessions,
    Duration? totalFocusedDuration,
    DateTime? lastCompletedDate,
    DateTime? lastActivityDate,
    int? currentLevel,
  }) {
    return FocusProfile(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalPoints: totalPoints ?? this.totalPoints,
      totalExperience: totalExperience ?? this.totalExperience,
      completedSessions: completedSessions ?? this.completedSessions,
      cancelledSessions: cancelledSessions ?? this.cancelledSessions,
      totalFocusedDuration: totalFocusedDuration ?? this.totalFocusedDuration,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      currentLevel: currentLevel ?? this.currentLevel,
    );
  }

  /// Converts the profile into JSON-compatible values.
  Map<String, Object?> toJson() => {
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'totalPoints': totalPoints,
    'totalExperience': totalExperience,
    'completedSessions': completedSessions,
    'cancelledSessions': cancelledSessions,
    'totalFocusedDuration': totalFocusedDuration.inSeconds,
    'lastCompletedDate': lastCompletedDate?.toIso8601String(),
    'lastActivityDate': lastActivityDate?.toIso8601String(),
    'currentLevel': currentLevel,
  };

  /// Restores a profile from JSON-compatible values.
  factory FocusProfile.fromJson(Map<String, Object?> json) {
    return FocusProfile(
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      totalPoints: json['totalPoints'] as int? ?? 0,
      totalExperience: json['totalExperience'] as int? ?? 0,
      completedSessions: json['completedSessions'] as int? ?? 0,
      cancelledSessions: json['cancelledSessions'] as int? ?? 0,
      totalFocusedDuration: Duration(
        seconds: json['totalFocusedDuration'] as int? ?? 0,
      ),
      lastCompletedDate: json['lastCompletedDate'] == null
          ? null
          : DateTime.parse(json['lastCompletedDate'] as String),
      lastActivityDate: json['lastActivityDate'] == null
          ? null
          : DateTime.parse(json['lastActivityDate'] as String),
      currentLevel: json['currentLevel'] as int? ?? 1,
    );
  }
}
