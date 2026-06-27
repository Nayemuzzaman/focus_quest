import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:focus_quest/src/config/focus_quest_config.dart';
import 'package:focus_quest/src/exceptions/focus_quest_exception.dart';
import 'package:focus_quest/src/feedback/focus_feedback.dart';
import 'package:focus_quest/src/lifecycle/focus_lifecycle.dart';
import 'package:focus_quest/src/models/focus_profile.dart';
import 'package:focus_quest/src/models/focus_reward.dart';
import 'package:focus_quest/src/models/focus_session.dart';
import 'package:focus_quest/src/models/focus_statistics.dart';
import 'package:focus_quest/src/models/focus_state.dart';
import 'package:focus_quest/src/rewards/focus_reward_strategy.dart';
import 'package:focus_quest/src/storage/focus_quest_storage.dart';
import 'package:focus_quest/src/utilities/focus_clock.dart';

/// The main public controller for managing focus sessions and statistics.
class FocusQuestController extends ChangeNotifier {
  /// Creates a controller with optional custom dependencies.
  FocusQuestController({
    FocusQuestConfig? config,
    FocusClock? clock,
    FocusQuestStorage? storage,
    RewardStrategy? rewardStrategy,
    FocusFeedback? feedback,
    this.lifecycleHandler,
  }) : config = config ?? const FocusQuestConfig(),
       _clock = clock ?? const SystemFocusClock(),
       _storage = storage ?? InMemoryFocusQuestStorage(),
       _rewardStrategy = rewardStrategy ?? const DefaultRewardStrategy(),
       _feedback = feedback ?? const NoopFocusFeedback();

  /// Configuration used by session, reward, lifecycle, and streak logic.
  final FocusQuestConfig config;
  final FocusClock _clock;
  final FocusQuestStorage _storage;
  final RewardStrategy _rewardStrategy;
  final FocusFeedback _feedback;

  /// Optional lifecycle hook for host-app integrations.
  final FocusLifecycleHandler? lifecycleHandler;

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  FocusSession? _activeSession;
  List<FocusSession> _sessionHistory = <FocusSession>[];
  FocusProfile _profile = const FocusProfile();
  FocusQuestState _state = const FocusQuestState();
  Timer? _ticker;
  bool _isCompletingFromTick = false;

  /// Current immutable state snapshot.
  FocusQuestState get state => _state;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _isInitialized;

  /// Whether initialization or another async action is in progress.
  bool get isLoading => _isLoading;

  /// Last controller error message, if any.
  String? get error => _error;

  /// Current active session, if one is running or paused.
  FocusSession? get activeSession => _activeSession;

  /// Copy of all persisted sessions.
  List<FocusSession> get sessionHistory =>
      List<FocusSession>.from(_sessionHistory);

  /// Current profile snapshot.
  FocusProfile get profile => _profile;

  /// Initializes storage and restores persisted sessions/profile state.
  Future<void> initialize() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _error = null;
    _syncState(isLoading: true);

    try {
      await _storage.initialize();
      final sessions = await _storage.loadSessions();
      final profile = await _storage.loadProfile();
      _sessionHistory = sessions;
      _profile = profile ?? const FocusProfile();
      _activeSession = sessions
          .where((session) => _isActive(session))
          .toList()
          .lastOrNull;
      if (_activeSession != null) {
        final advanced = _advanceSession(_activeSession!, _clock.now());
        if (advanced.status == FocusSessionStatus.completed) {
          await _finalizeSession(advanced, completed: true);
        } else {
          _activeSession = advanced;
          await _persistSession(advanced);
          _startTickerIfNeeded();
        }
      }
      _isInitialized = true;
      _syncState();
    } catch (error) {
      _error = error.toString();
      _syncState();
    } finally {
      _isLoading = false;
      _syncState();
    }
  }

  /// Starts a new focus session.
  Future<void> start({
    Duration? duration,
    Map<String, Object?>? metadata,
  }) async {
    _guardInitialized();
    if (_activeSession != null && _isActive(_activeSession!)) {
      throw const FocusQuestException(
        'An active session is already in progress.',
      );
    }

    final now = _clock.now();
    _activeSession = FocusSession(
      id: _generateId(),
      startedAt: now,
      targetDuration: duration ?? config.defaultSessionDuration,
      status: FocusSessionStatus.running,
      metadata: metadata ?? const {},
      lastResumedAt: now,
    );

    await _persistSession(_activeSession!);
    await _feedback.onSessionStarted();
    _startTickerIfNeeded();
    _syncState();
  }

  /// Pauses the active running session.
  Future<void> pause() async {
    _guardInitialized();
    final active = _ensureActiveSession();
    if (active.status != FocusSessionStatus.running) {
      throw const FocusQuestException('Only a running session can be paused.');
    }

    final updated = _advanceSession(active, _clock.now()).copyWith(
      status: FocusSessionStatus.paused,
      pauseCount: active.pauseCount + 1,
      lastResumedAt: null,
    );
    _activeSession = updated;
    await _persistSession(updated);
    await _feedback.onSessionPaused();
    _stopTicker();
    _syncState();
  }

  /// Resumes the active paused session.
  Future<void> resume() async {
    _guardInitialized();
    final active = _ensureActiveSession();
    if (active.status != FocusSessionStatus.paused) {
      throw const FocusQuestException('Only a paused session can be resumed.');
    }

    final now = _clock.now();
    final updated = active.copyWith(
      status: FocusSessionStatus.running,
      lastResumedAt: now,
    );
    _activeSession = updated;
    await _persistSession(updated);
    await _feedback.onSessionResumed();
    _startTickerIfNeeded();
    _syncState();
  }

  /// Completes the active session and applies rewards.
  Future<void> complete() async {
    _guardInitialized();
    final active = _ensureActiveSession();
    if (active.status == FocusSessionStatus.completed ||
        active.status == FocusSessionStatus.cancelled ||
        active.status == FocusSessionStatus.failed) {
      throw StateError('The session is already completed.');
    }

    final now = _clock.now();
    final advanced = _advanceSession(active, now);
    final completed = advanced.copyWith(
      status: FocusSessionStatus.completed,
      completedAt: now,
    );
    final updated = completed.copyWith(
      reward: _rewardStrategy.calculate(completed, config),
    );
    await _finalizeSession(updated, completed: true);
    await _feedback.onSessionCompleted();
    _stopTicker();
    _syncState();
  }

  /// Cancels the active session with an optional [reason].
  Future<void> cancel({String? reason}) async {
    _guardInitialized();
    final active = _ensureActiveSession();
    if (active.status == FocusSessionStatus.completed ||
        active.status == FocusSessionStatus.cancelled ||
        active.status == FocusSessionStatus.failed) {
      throw const FocusQuestException('The session is already completed.');
    }

    final now = _clock.now();
    final advanced = _advanceSession(active, now);
    final cancelled = advanced.copyWith(
      status: FocusSessionStatus.cancelled,
      completedAt: now,
      failureReason: reason,
    );
    final updated = cancelled.copyWith(
      reward: _rewardStrategy.calculate(cancelled, config),
    );
    await _finalizeSession(updated, completed: false);
    await _feedback.onSessionCancelled();
    _stopTicker();
    _syncState();
  }

  /// Resets active state and finalizes any active session without rewards.
  Future<void> reset() async {
    _guardInitialized();
    final active = _activeSession;
    if (active != null && _isActive(active)) {
      final now = _clock.now();
      final resetSession = _advanceSession(active, now).copyWith(
        status: FocusSessionStatus.cancelled,
        completedAt: now,
        failureReason: 'Session reset.',
        reward: const FocusReward(points: 0, experience: 0),
      );
      await _finalizeSession(resetSession, completed: false);
    } else {
      _activeSession = null;
    }
    _error = null;
    _stopTicker();
    _syncState();
  }

  /// Recomputes statistics from the current in-memory state.
  Future<void> refreshStatistics() async {
    _guardInitialized();
    _syncState();
  }

  /// Disposes timers and listener resources.
  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  /// Clears the current error message.
  Future<void> clearError() async {
    _error = null;
    _syncState();
  }

  /// Applies focus-session behavior for a host app lifecycle [event].
  Future<void> handleLifecycleEvent(FocusLifecycleEvent event) async {
    if (_activeSession == null || !_isActive(_activeSession!)) {
      await lifecycleHandler?.handleLifecycleEvent(event);
      return;
    }

    if (event == FocusLifecycleEvent.paused) {
      final interrupted = _activeSession!.copyWith(
        interruptionCount: _activeSession!.interruptionCount + 1,
      );
      _activeSession = interrupted;
      await _persistSession(interrupted);

      if (interrupted.interruptionCount > config.maxInterruptions) {
        await _fail(reason: 'Maximum interruptions exceeded.');
        await lifecycleHandler?.handleLifecycleEvent(event);
        return;
      }

      if (config.backgroundBehavior == BackgroundBehavior.pause) {
        await pause();
      } else if (config.backgroundBehavior == BackgroundBehavior.cancel) {
        await cancel(reason: 'App moved to background.');
      }
    }

    await lifecycleHandler?.handleLifecycleEvent(event);
  }

  void _guardInitialized() {
    if (!_isInitialized) {
      throw const FocusQuestException(
        'The controller must be initialized before use.',
      );
    }
  }

  FocusSession _ensureActiveSession() {
    final active = _activeSession;
    if (active == null) {
      throw const FocusQuestException('No active session exists.');
    }
    return active;
  }

  bool _isActive(FocusSession session) {
    return session.status == FocusSessionStatus.running ||
        session.status == FocusSessionStatus.paused;
  }

  Future<void> _fail({String? reason}) async {
    final active = _ensureActiveSession();
    final now = _clock.now();
    final updated = _advanceSession(active, now).copyWith(
      status: FocusSessionStatus.failed,
      completedAt: now,
      failureReason: reason,
      reward: const FocusReward(points: 0, experience: 0),
    );
    await _finalizeSession(updated, completed: false);
    _stopTicker();
    _syncState();
  }

  FocusSession _advanceSession(FocusSession session, DateTime now) {
    if (session.status != FocusSessionStatus.running) {
      return session;
    }

    final advanced = session.advanceTo(now);
    if (advanced.actualFocusDuration >= advanced.targetDuration) {
      final completed = advanced.copyWith(
        status: FocusSessionStatus.completed,
        completedAt: now,
      );
      return completed.copyWith(
        reward: _rewardStrategy.calculate(completed, config),
      );
    }
    return advanced;
  }

  Future<void> _finalizeSession(
    FocusSession session, {
    required bool completed,
  }) async {
    _activeSession = null;
    _sessionHistory =
        _sessionHistory.where((item) => item.id != session.id).toList()
          ..add(session);
    await _persistSession(session);
    await _updateProfileForSession(session, completed: completed);
  }

  Future<void> _persistSession(FocusSession session) async {
    await _storage.saveSession(session);
    _sessionHistory = await _storage.loadSessions();
  }

  Future<void> _updateProfileForSession(
    FocusSession session, {
    required bool completed,
  }) async {
    final streak = _calculateStreak(_sessionHistory);
    final totalExperience =
        _profile.totalExperience + (session.reward?.experience ?? 0);
    final updatedProfile = _profile.copyWith(
      totalPoints: _profile.totalPoints + (session.reward?.points ?? 0),
      totalExperience: totalExperience,
      completedSessions: _profile.completedSessions + (completed ? 1 : 0),
      cancelledSessions: _profile.cancelledSessions + (completed ? 0 : 1),
      totalFocusedDuration:
          _profile.totalFocusedDuration + session.actualFocusDuration,
      lastCompletedDate: completed
          ? _startOfDay(_clock.now())
          : _profile.lastCompletedDate,
      lastActivityDate: _clock.now(),
      currentLevel: _currentLevelForExperience(totalExperience),
      currentStreak: streak.current,
      longestStreak: streak.longest,
    );

    _profile = updatedProfile;
    await _storage.saveProfile(updatedProfile);
  }

  ({int current, int longest}) _calculateStreak(List<FocusSession> sessions) {
    final qualifyingDays = <DateTime>{};
    final focusedByDay = <DateTime, Duration>{};
    final minimum = Duration(minutes: config.streakMinimumDailyTargetMinutes);

    for (final session in sessions) {
      if (session.status != FocusSessionStatus.completed ||
          session.completedAt == null) {
        continue;
      }
      final day = _startOfDay(session.completedAt!);
      focusedByDay[day] =
          (focusedByDay[day] ?? Duration.zero) + session.actualFocusDuration;
    }

    for (final entry in focusedByDay.entries) {
      if (entry.value >= minimum) {
        qualifyingDays.add(entry.key);
      }
    }

    if (qualifyingDays.isEmpty) {
      return (current: 0, longest: 0);
    }

    final sortedDays = qualifyingDays.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var index = 1; index < sortedDays.length; index += 1) {
      if (sortedDays[index].difference(sortedDays[index - 1]).inDays == 1) {
        run += 1;
      } else {
        run = 1;
      }
      longest = max(longest, run);
    }

    final today = _startOfDay(_clock.now());
    final yesterday = today.subtract(const Duration(days: 1));
    var current = 0;
    var cursor = qualifyingDays.contains(today) ? today : yesterday;
    while (qualifyingDays.contains(cursor)) {
      current += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return (current: current, longest: longest);
  }

  int _currentLevelForExperience(int experience) {
    if (experience <= 0) {
      return 1;
    }
    final level =
        (log(experience / config.levelBaseXp) / log(config.levelExponent))
            .floor();
    return max(1, level + 1);
  }

  String _generateId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = Random().nextInt(100000).toString().padLeft(5, '0');
    return 'session_$time$suffix';
  }

  void _syncState({bool isLoading = false}) {
    final active = _activeSession;
    final currentStatus = active?.status ?? FocusSessionStatus.idle;
    final remaining = active?.remainingDuration ?? Duration.zero;
    final elapsed = active?.actualFocusDuration ?? Duration.zero;
    final statistics = _buildStatistics();
    _state = FocusQuestState(
      activeSession: active,
      status: currentStatus,
      remainingDuration: remaining,
      elapsedFocusDuration: elapsed,
      focusedToday: statistics.focusedToday,
      dailyGoalProgress: _dailyGoalProgress(statistics.focusedToday),
      currentStreak: statistics.currentStreak,
      longestStreak: statistics.longestStreak,
      totalPoints: statistics.totalPoints,
      currentLevel: statistics.currentLevel,
      sessionHistory: _sessionHistory,
      isLoading: isLoading || _isLoading,
      error: _error,
      statistics: statistics,
    );
    notifyListeners();
  }

  FocusStatistics _buildStatistics() {
    final now = _clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final focusedToday = _sessionHistory
        .where(
          (session) =>
              session.status == FocusSessionStatus.completed &&
              session.completedAt != null,
        )
        .fold<Duration>(Duration.zero, (duration, session) {
          final completedDay = DateTime(
            session.completedAt!.year,
            session.completedAt!.month,
            session.completedAt!.day,
          );
          if (completedDay == today) {
            return duration + session.actualFocusDuration;
          }
          return duration;
        });

    final focusedThisWeek = _sessionHistory
        .where(
          (session) =>
              session.status == FocusSessionStatus.completed &&
              session.completedAt != null,
        )
        .fold<Duration>(Duration.zero, (duration, session) {
          final completedDay = DateTime(
            session.completedAt!.year,
            session.completedAt!.month,
            session.completedAt!.day,
          );
          if (completedDay.isAfter(
                weekStart.subtract(const Duration(days: 1)),
              ) &&
              !completedDay.isAfter(today)) {
            return duration + session.actualFocusDuration;
          }
          return duration;
        });

    final focusedThisMonth = _sessionHistory
        .where(
          (session) =>
              session.status == FocusSessionStatus.completed &&
              session.completedAt != null,
        )
        .fold<Duration>(Duration.zero, (duration, session) {
          final completedDay = DateTime(
            session.completedAt!.year,
            session.completedAt!.month,
            session.completedAt!.day,
          );
          if (completedDay.isAfter(
                monthStart.subtract(const Duration(days: 1)),
              ) &&
              !completedDay.isAfter(today)) {
            return duration + session.actualFocusDuration;
          }
          return duration;
        });

    final completedSessions = _sessionHistory
        .where((session) => session.status == FocusSessionStatus.completed)
        .length;
    final cancelledSessions = _sessionHistory
        .where((session) => session.status == FocusSessionStatus.cancelled)
        .length;
    final completionRate = completedSessions + cancelledSessions == 0
        ? 0.0
        : (completedSessions / (completedSessions + cancelledSessions) * 100)
              .toDouble();
    final totalPoints = _profile.totalPoints;
    final totalExperience = _profile.totalExperience;
    final currentLevel = _profile.currentLevel;
    final progressToNextLevel = (totalExperience % config.levelBaseXp).toInt();

    return FocusStatistics(
      focusedToday: focusedToday,
      focusedThisWeek: focusedThisWeek,
      focusedThisMonth: focusedThisMonth,
      totalFocused: _profile.totalFocusedDuration,
      completedSessions: completedSessions,
      cancelledSessions: cancelledSessions,
      completionRate: completionRate,
      currentStreak: _profile.currentStreak,
      longestStreak: _profile.longestStreak,
      totalPoints: totalPoints,
      totalExperience: totalExperience,
      currentLevel: currentLevel,
      progressToNextLevel: progressToNextLevel,
    );
  }

  double _dailyGoalProgress(Duration focusedToday) {
    final goal = config.dailyGoalDuration.inSeconds;
    if (goal <= 0) {
      return 0;
    }
    return min(1.0, focusedToday.inSeconds / goal);
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  void _startTickerIfNeeded() {
    if (_activeSession?.status != FocusSessionStatus.running ||
        _ticker != null) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _onTick();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _onTick() async {
    if (_isCompletingFromTick ||
        _activeSession?.status != FocusSessionStatus.running) {
      return;
    }

    final advanced = _advanceSession(_activeSession!, _clock.now());
    _activeSession = advanced;
    if (advanced.status == FocusSessionStatus.completed) {
      _isCompletingFromTick = true;
      try {
        await _finalizeSession(advanced, completed: true);
        await _feedback.onSessionCompleted();
        _stopTicker();
      } finally {
        _isCompletingFromTick = false;
      }
    }
    _syncState();
  }
}

extension _LastOrNull<T> on Iterable<T> {
  T? get lastOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    T? result = iterator.current;
    while (iterator.moveNext()) {
      result = iterator.current;
    }
    return result;
  }
}
