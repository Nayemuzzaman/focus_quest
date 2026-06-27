import 'package:focus_quest/src/models/focus_session.dart';
import 'package:focus_quest/src/models/focus_statistics.dart';

/// Immutable state emitted by the focus quest controller.
class FocusQuestState {
  /// Creates a controller state snapshot.
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

  /// Currently active session, if one is running or paused.
  final FocusSession? activeSession;

  /// Current session status.
  final FocusSessionStatus status;

  /// Remaining duration for the active session.
  final Duration remainingDuration;

  /// Elapsed focused duration for the active session.
  final Duration elapsedFocusDuration;

  /// Focused duration completed today.
  final Duration focusedToday;

  /// Daily goal progress from 0.0 to 1.0.
  final double dailyGoalProgress;

  /// Current qualifying focus-day streak.
  final int currentStreak;

  /// Longest qualifying focus-day streak.
  final int longestStreak;

  /// Total points earned.
  final int totalPoints;

  /// Current level derived from experience.
  final int currentLevel;

  /// Persisted session history.
  final List<FocusSession> sessionHistory;

  /// Whether the controller is performing an async operation.
  final bool isLoading;

  /// Last user-facing error message, if any.
  final String? error;

  /// Full calculated statistics snapshot.
  final FocusStatistics statistics;
}
