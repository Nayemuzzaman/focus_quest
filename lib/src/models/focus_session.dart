import 'package:focus_quest/src/models/focus_reward.dart';

/// Lifecycle status for a focus session.
enum FocusSessionStatus { idle, running, paused, completed, cancelled, failed }

/// Represents one focus session and its current lifecycle state.
class FocusSession {
  /// Creates a focus session value.
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.targetDuration,
    this.actualFocusDuration = Duration.zero,
    this.status = FocusSessionStatus.idle,
    this.pauseCount = 0,
    this.interruptionCount = 0,
    this.reward,
    this.metadata = const {},
    this.failureReason,
    this.completedAt,
    this.lastResumedAt,
  });

  /// Unique session identifier.
  final String id;

  /// Time when the session was started.
  final DateTime startedAt;

  /// Time when the session reached a final state.
  final DateTime? completedAt;

  /// Intended focused duration.
  final Duration targetDuration;

  /// Actual accumulated focused duration.
  final Duration actualFocusDuration;

  /// Current lifecycle status.
  final FocusSessionStatus status;

  /// Number of times the session has been paused.
  final int pauseCount;

  /// Number of lifecycle interruptions recorded for the session.
  final int interruptionCount;

  /// Reward earned by the finalized session.
  final FocusReward? reward;

  /// App-specific metadata attached to the session.
  final Map<String, Object?> metadata;

  /// Reason for cancellation or failure.
  final String? failureReason;

  /// Last timestamp when a running session resumed.
  final DateTime? lastResumedAt;

  /// Remaining duration, clamped to zero.
  Duration get remainingDuration {
    final remaining = targetDuration.inSeconds - actualFocusDuration.inSeconds;
    return Duration(seconds: remaining > 0 ? remaining : 0);
  }

  /// Returns a copy with selected fields replaced.
  FocusSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? completedAt,
    Duration? targetDuration,
    Duration? actualFocusDuration,
    FocusSessionStatus? status,
    int? pauseCount,
    int? interruptionCount,
    FocusReward? reward,
    Map<String, Object?>? metadata,
    String? failureReason,
    DateTime? lastResumedAt,
  }) {
    return FocusSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      targetDuration: targetDuration ?? this.targetDuration,
      actualFocusDuration: actualFocusDuration ?? this.actualFocusDuration,
      status: status ?? this.status,
      pauseCount: pauseCount ?? this.pauseCount,
      interruptionCount: interruptionCount ?? this.interruptionCount,
      reward: reward ?? this.reward,
      metadata: metadata ?? this.metadata,
      failureReason: failureReason ?? this.failureReason,
      lastResumedAt: lastResumedAt ?? this.lastResumedAt,
    );
  }

  /// Advances focused duration to [now] using timestamps.
  FocusSession advanceTo(DateTime now) {
    if (status != FocusSessionStatus.running || lastResumedAt == null) {
      return this;
    }

    final elapsed = now.difference(lastResumedAt!);
    if (elapsed.inSeconds <= 0) {
      return this;
    }

    return copyWith(
      actualFocusDuration: actualFocusDuration + elapsed,
      lastResumedAt: now,
    );
  }

  /// Converts the session into JSON-compatible values.
  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'targetDuration': targetDuration.inSeconds,
    'actualFocusDuration': actualFocusDuration.inSeconds,
    'status': status.name,
    'pauseCount': pauseCount,
    'interruptionCount': interruptionCount,
    'reward': reward?.toJson(),
    'metadata': metadata,
    'failureReason': failureReason,
    'lastResumedAt': lastResumedAt?.toIso8601String(),
  };

  /// Restores a session from JSON-compatible values.
  factory FocusSession.fromJson(Map<String, Object?> json) {
    return FocusSession(
      id: json['id'] as String? ?? '',
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      targetDuration: Duration(seconds: json['targetDuration'] as int? ?? 0),
      actualFocusDuration: Duration(
        seconds: json['actualFocusDuration'] as int? ?? 0,
      ),
      status: FocusSessionStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => FocusSessionStatus.idle,
      ),
      pauseCount: json['pauseCount'] as int? ?? 0,
      interruptionCount: json['interruptionCount'] as int? ?? 0,
      reward: json['reward'] == null
          ? null
          : FocusReward.fromJson(
              Map<String, Object?>.from(json['reward'] as Map),
            ),
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
      failureReason: json['failureReason'] as String?,
      lastResumedAt: json['lastResumedAt'] == null
          ? null
          : DateTime.parse(json['lastResumedAt'] as String),
    );
  }
}
