import 'package:focus_quest/src/models/focus_session.dart';

/// Something that happened in a focus quest, emitted by
/// `FocusQuestController.events`.
///
/// The hierarchy is sealed, so a `switch` over a [FocusQuestEvent] can be
/// exhaustive. Events are emitted after the controller state has been
/// updated, so reading the controller state from a listener always reflects
/// the event.
sealed class FocusQuestEvent {
  /// Allows subclasses to declare const constructors.
  const FocusQuestEvent({required this.occurredAt});

  /// Clock time at which the controller emitted the event.
  ///
  /// For a session completed while the app was not running this is the time
  /// the completion was detected; see [FocusSession.completedAt] for the
  /// moment the target was actually reached.
  final DateTime occurredAt;
}

/// An event describing a change to one focus session.
sealed class FocusSessionEvent extends FocusQuestEvent {
  /// Allows subclasses to declare const constructors.
  const FocusSessionEvent({required this.session, required super.occurredAt});

  /// Snapshot of the session right after the change.
  final FocusSession session;
}

/// A new session started running.
final class FocusSessionStartedEvent extends FocusSessionEvent {
  /// Creates a session-started event.
  const FocusSessionStartedEvent({
    required super.session,
    required super.occurredAt,
  });
}

/// A running session was paused, by the user or by background behavior.
final class FocusSessionPausedEvent extends FocusSessionEvent {
  /// Creates a session-paused event.
  const FocusSessionPausedEvent({
    required super.session,
    required super.occurredAt,
  });
}

/// A paused session resumed running.
final class FocusSessionResumedEvent extends FocusSessionEvent {
  /// Creates a session-resumed event.
  const FocusSessionResumedEvent({
    required super.session,
    required super.occurredAt,
  });
}

/// A session reached a completed state and its reward was applied.
final class FocusSessionCompletedEvent extends FocusSessionEvent {
  /// Creates a session-completed event.
  const FocusSessionCompletedEvent({
    required super.session,
    required super.occurredAt,
    this.completedWhileAway = false,
  });

  /// Whether the session reached its target while the app was not running and
  /// was completed during `FocusQuestController.initialize`.
  final bool completedWhileAway;
}

/// A session was cancelled, including by `reset` or background behavior.
final class FocusSessionCancelledEvent extends FocusSessionEvent {
  /// Creates a session-cancelled event.
  const FocusSessionCancelledEvent({
    required super.session,
    required super.occurredAt,
  });
}

/// A session failed, for example after too many interruptions.
final class FocusSessionFailedEvent extends FocusSessionEvent {
  /// Creates a session-failed event.
  const FocusSessionFailedEvent({
    required super.session,
    required super.occurredAt,
  });
}

/// A finalized session raised the profile level.
final class FocusLevelUpEvent extends FocusQuestEvent {
  /// Creates a level-up event.
  const FocusLevelUpEvent({
    required this.previousLevel,
    required this.newLevel,
    required super.occurredAt,
  });

  /// Level before the session was finalized.
  final int previousLevel;

  /// Level after the session was finalized.
  final int newLevel;
}

/// A finalized session increased the current streak.
final class FocusStreakIncreasedEvent extends FocusQuestEvent {
  /// Creates a streak-increased event.
  const FocusStreakIncreasedEvent({
    required this.previousStreak,
    required this.currentStreak,
    required super.occurredAt,
  });

  /// Current streak before the session was finalized.
  final int previousStreak;

  /// Current streak after the session was finalized.
  final int currentStreak;
}

/// Today's focused time reached the configured daily goal.
///
/// Emitted at most once per calendar day, by the session that crosses the
/// goal.
final class FocusDailyGoalReachedEvent extends FocusQuestEvent {
  /// Creates a daily-goal-reached event.
  const FocusDailyGoalReachedEvent({
    required this.focusedToday,
    required this.dailyGoal,
    required super.occurredAt,
  });

  /// Focused time today, including the session that reached the goal.
  final Duration focusedToday;

  /// The configured `FocusQuestConfig.dailyGoalDuration`.
  final Duration dailyGoal;
}
