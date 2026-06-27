class FocusProfile {
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

  final int currentStreak;
  final int longestStreak;
  final int totalPoints;
  final int totalExperience;
  final int completedSessions;
  final int cancelledSessions;
  final Duration totalFocusedDuration;
  final DateTime? lastCompletedDate;
  final DateTime? lastActivityDate;
  final int currentLevel;

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
