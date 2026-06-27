import 'package:focus_quest/src/models/focus_session.dart';
import 'package:focus_quest/src/models/focus_statistics.dart';

/// Immutable state emitted by the focus quest controller.
class FocusQuestState {
  const FocusQuestState({
    this.activeSession,
    this.status = FocusSessionStatus.idle,
    this.remainingDuration = Duration.zero,
    this.elapsedFocusDuration = Duration.zero,
    this.focusedToday = Duration.zero,
    this.dailyGoalProgress = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPoints = 0,
    this.currentLevel = 1,
    this.sessionHistory = const <FocusSession>[],
    this.isLoading = false,
    this.error,
    this.statistics = const FocusStatistics(),
  });

  final FocusSession? activeSession;
  final FocusSessionStatus status;
  final Duration remainingDuration;
  final Duration elapsedFocusDuration;
  final Duration focusedToday;
  final double dailyGoalProgress;
  final int currentStreak;
  final int longestStreak;
  final int totalPoints;
  final int currentLevel;
  final List<FocusSession> sessionHistory;
  final bool isLoading;
  final String? error;
  final FocusStatistics statistics;
}
