import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:focus_quest/src/config/focus_quest_config.dart';
import 'package:focus_quest/src/events/focus_quest_event.dart';
import 'package:focus_quest/src/exceptions/focus_quest_exception.dart';
import 'package:focus_quest/src/feedback/focus_feedback.dart';
import 'package:focus_quest/src/lifecycle/focus_lifecycle.dart';
import 'package:focus_quest/src/models/focus_profile.dart';
import 'package:focus_quest/src/models/focus_reward.dart';
import 'package:focus_quest/src/models/focus_session.dart';
import 'package:focus_quest/src/models/focus_statistics.dart';
import 'package:focus_quest/src/models/focus_state.dart';
import 'package:focus_quest/src/rewards/focus_level_strategy.dart';
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
    LevelStrategy? levelStrategy,
    FocusFeedback? feedback,
    this.lifecycleHandler,
  }) : config = config ?? const FocusQuestConfig(),
       _clock = clock ?? const SystemFocusClock(),
       _storage = storage ?? InMemoryFocusQuestStorage(),
       _rewardStrategy = rewardStrategy ?? const DefaultRewardStrategy(),
       _levelStrategy = levelStrategy ?? const DefaultLevelStrategy(),
       _feedback = feedback ?? const NoopFocusFeedback();

  /// Configuration used by session, reward, lifecycle, and streak logic.
  final FocusQuestConfig config;
  final FocusClock _clock;
  final FocusQuestStorage _storage;
  final RewardStrategy _rewardStrategy;
  final LevelStrategy _levelStrategy;
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
  Future<void> _lifecycleQueue = Future<void>.value();
  _HistoryAggregates? _aggregates;
  List<FocusSession>? _aggregatesSource;
  DateTime? _aggregatesDay;
  final StreamController<FocusQuestEvent> _events =
      StreamController<FocusQuestEvent>.broadcast();

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

  /// Broadcast stream of session transitions and progress milestones.
  ///
  /// Events are emitted after [state] has been updated and before
  /// [FocusFeedback] hooks run. Subscribe before calling [initialize] to
  /// receive a completion for a session that finished while the app was not
  /// running. The stream closes when the controller is disposed.
  Stream<FocusQuestEvent> get events => _events.stream;

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
      _profile = await _reconcileProfileLevel(profile ?? const FocusProfile());
      _activeSession = sessions
          .where((session) => _isActive(session))
          .toList()
          .lastOrNull;
      var completedWhileAway = false;
      var leveledUp = false;
      FocusSession? restoredCompletion;
      _ProgressSnapshot? before;
      if (_activeSession != null) {
        final advanced = _advanceSession(_activeSession!, _clock.now());
        if (advanced.status == FocusSessionStatus.completed) {
          completedWhileAway = true;
          restoredCompletion = advanced;
          before = _progressSnapshot();
          leveledUp = await _finalizeSession(advanced, completed: true);
        } else {
          _activeSession = advanced;
          await _persistSession(advanced);
          _startTickerIfNeeded();
        }
      }
      _isInitialized = true;
      _syncState();
      if (completedWhileAway) {
        _publishFinalized(
          FocusSessionCompletedEvent(
            session: restoredCompletion!,
            occurredAt: _clock.now(),
            completedWhileAway: true,
          ),
          before!,
        );
        await _notifyFeedback(_feedback.onSessionCompleted);
        if (leveledUp) {
          await _notifyFeedback(_feedback.onLevelUp);
        }
      }
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

    final targetDuration = duration ?? config.defaultSessionDuration;
    if (targetDuration <= Duration.zero) {
      throw const FocusQuestException('Session duration must be positive.');
    }

    final now = _clock.now();
    final session = FocusSession(
      id: _generateId(),
      startedAt: now,
      targetDuration: targetDuration,
      status: FocusSessionStatus.running,
      metadata: metadata ?? const {},
      lastResumedAt: now,
    );

    await _persistSession(session);
    _activeSession = session;
    _startTickerIfNeeded();
    _syncState();
    _emit(FocusSessionStartedEvent(session: session, occurredAt: now));
    await _notifyFeedback(_feedback.onSessionStarted);
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
    _stopTicker();
    _syncState();
    _emit(FocusSessionPausedEvent(session: updated, occurredAt: _clock.now()));
    await _notifyFeedback(_feedback.onSessionPaused);
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
    _startTickerIfNeeded();
    _syncState();
    _emit(FocusSessionResumedEvent(session: updated, occurredAt: now));
    await _notifyFeedback(_feedback.onSessionResumed);
  }

  /// Completes the active session and applies rewards.
  Future<void> complete() async {
    _guardInitialized();
    final active = _ensureActiveSession();
    if (active.status == FocusSessionStatus.completed ||
        active.status == FocusSessionStatus.cancelled ||
        active.status == FocusSessionStatus.failed) {
      throw const FocusQuestException('The session is already completed.');
    }

    final now = _clock.now();
    final advanced = _advanceSession(active, now);
    final completed = advanced.copyWith(
      status: FocusSessionStatus.completed,
      completedAt: advanced.completedAt ?? now,
    );
    final updated = completed.copyWith(
      reward: _rewardStrategy.calculate(completed, config),
    );
    final before = _progressSnapshot();
    final leveledUp = await _finalizeSession(updated, completed: true);
    _stopTicker();
    _syncState();
    _publishFinalized(
      FocusSessionCompletedEvent(session: updated, occurredAt: now),
      before,
    );
    await _notifyFeedback(_feedback.onSessionCompleted);
    if (leveledUp) {
      await _notifyFeedback(_feedback.onLevelUp);
    }
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
    final before = _progressSnapshot();
    final leveledUp = await _finalizeSession(updated, completed: false);
    _stopTicker();
    _syncState();
    _publishFinalized(
      FocusSessionCancelledEvent(session: updated, occurredAt: now),
      before,
    );
    await _notifyFeedback(_feedback.onSessionCancelled);
    if (leveledUp) {
      await _notifyFeedback(_feedback.onLevelUp);
    }
  }

  /// Resets active state and finalizes any active session without rewards.
  Future<void> reset() async {
    _guardInitialized();
    final active = _activeSession;
    FocusSession? resetSession;
    _ProgressSnapshot? before;
    if (active != null && _isActive(active)) {
      final now = _clock.now();
      resetSession = _advanceSession(active, now).copyWith(
        status: FocusSessionStatus.cancelled,
        completedAt: now,
        failureReason: 'Session reset.',
        reward: const FocusReward(points: 0, experience: 0),
      );
      before = _progressSnapshot();
      await _finalizeSession(resetSession, completed: false);
    } else {
      _activeSession = null;
    }
    _error = null;
    _stopTicker();
    _syncState();
    if (resetSession != null && before != null) {
      _publishFinalized(
        FocusSessionCancelledEvent(
          session: resetSession,
          occurredAt: resetSession.completedAt ?? _clock.now(),
        ),
        before,
      );
    }
  }

  /// Recomputes statistics from the current in-memory state.
  Future<void> refreshStatistics() async {
    _guardInitialized();
    _syncState();
  }

  /// Disposes timers, closes [events], and releases listener resources.
  @override
  void dispose() {
    _stopTicker();
    unawaited(_events.close());
    super.dispose();
  }

  /// Clears the current error message.
  Future<void> clearError() async {
    _error = null;
    _syncState();
  }

  /// Applies focus-session behavior for a host app lifecycle [event].
  ///
  /// Only [FocusLifecycleEvent.paused] and [FocusLifecycleEvent.detached]
  /// affect the session, and only while it is running: each records one
  /// interruption and then applies [FocusQuestConfig.backgroundBehavior].
  /// Repeated events for an already paused session are ignored, so host apps
  /// may forward every platform lifecycle transition without double counting.
  /// [FocusLifecycleEvent.inactive] and [FocusLifecycleEvent.resumed] never
  /// change the session. Every event is forwarded to [lifecycleHandler].
  Future<void> handleLifecycleEvent(FocusLifecycleEvent event) {
    // Platforms emit several transitions back to back (inactive, hidden,
    // paused). Serialize them so each one observes the previous outcome.
    final next = _lifecycleQueue.then((_) => _applyLifecycleEvent(event));
    _lifecycleQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _applyLifecycleEvent(FocusLifecycleEvent event) async {
    final active = _activeSession;
    final isBackgrounding =
        event == FocusLifecycleEvent.paused ||
        event == FocusLifecycleEvent.detached;

    if (isBackgrounding &&
        active != null &&
        active.status == FocusSessionStatus.running) {
      final interrupted = active.copyWith(
        interruptionCount: active.interruptionCount + 1,
      );
      _activeSession = interrupted;
      await _persistSession(interrupted);

      if (interrupted.interruptionCount > config.maxInterruptions) {
        await _fail(reason: 'Maximum interruptions exceeded.');
      } else if (config.backgroundBehavior == BackgroundBehavior.pause) {
        await pause();
      } else if (config.backgroundBehavior == BackgroundBehavior.cancel) {
        await cancel(reason: 'App moved to background.');
      } else {
        _syncState();
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
    final before = _progressSnapshot();
    await _finalizeSession(updated, completed: false);
    _stopTicker();
    _syncState();
    _publishFinalized(
      FocusSessionFailedEvent(session: updated, occurredAt: now),
      before,
    );
  }

  FocusSession _advanceSession(FocusSession session, DateTime now) {
    if (session.status != FocusSessionStatus.running) {
      return session;
    }

    final advanced = session.advanceTo(now);
    if (advanced.actualFocusDuration < advanced.targetDuration) {
      return advanced;
    }

    // The target may have been reached long before this call (for example
    // when restoring after the app was killed), so finalize at the moment it
    // was actually reached and never credit more than the target.
    final resumedAt = session.lastResumedAt;
    final remainingBefore =
        session.targetDuration - session.actualFocusDuration;
    var reachedAt = resumedAt == null || remainingBefore <= Duration.zero
        ? (resumedAt ?? now)
        : resumedAt.add(remainingBefore);
    if (reachedAt.isAfter(now)) {
      reachedAt = now;
    }
    final completed = advanced.copyWith(
      actualFocusDuration: advanced.targetDuration,
      status: FocusSessionStatus.completed,
      completedAt: reachedAt,
      lastResumedAt: reachedAt,
    );
    return completed.copyWith(
      reward: _rewardStrategy.calculate(completed, config),
    );
  }

  /// Persists a finalized [session], updates the profile, and returns whether
  /// the profile level increased.
  Future<bool> _finalizeSession(
    FocusSession session, {
    required bool completed,
  }) async {
    _activeSession = null;
    _sessionHistory =
        _sessionHistory.where((item) => item.id != session.id).toList()
          ..add(session);
    await _persistSession(session);
    return _updateProfileForSession(session, completed: completed);
  }

  Future<void> _persistSession(FocusSession session) async {
    await _storage.saveSession(session);
    _sessionHistory = await _storage.loadSessions();
  }

  Future<bool> _updateProfileForSession(
    FocusSession session, {
    required bool completed,
  }) async {
    final aggregates = _historyAggregates();
    final totalExperience =
        _profile.totalExperience + (session.reward?.experience ?? 0);
    final newLevel = _levelStrategy.levelForExperience(totalExperience, config);
    final leveledUp = newLevel > _profile.currentLevel;
    final updatedProfile = _profile.copyWith(
      totalPoints: _profile.totalPoints + (session.reward?.points ?? 0),
      totalExperience: totalExperience,
      completedSessions: _profile.completedSessions + (completed ? 1 : 0),
      cancelledSessions: _profile.cancelledSessions + (completed ? 0 : 1),
      totalFocusedDuration:
          _profile.totalFocusedDuration + session.actualFocusDuration,
      lastCompletedDate: completed
          ? _startOfDay(session.completedAt ?? _clock.now())
          : _profile.lastCompletedDate,
      lastActivityDate: _clock.now(),
      currentLevel: newLevel,
      currentStreak: aggregates.currentStreak,
      longestStreak: aggregates.longestStreak,
    );

    _profile = updatedProfile;
    await _storage.saveProfile(updatedProfile);
    return leveledUp;
  }

  /// Recomputes the stored level from total experience so profiles written by
  /// an older level formula (or a different strategy) stay consistent.
  Future<FocusProfile> _reconcileProfileLevel(FocusProfile profile) async {
    final level = _levelStrategy.levelForExperience(
      profile.totalExperience,
      config,
    );
    if (level == profile.currentLevel) {
      return profile;
    }
    final reconciled = profile.copyWith(currentLevel: level);
    await _storage.saveProfile(reconciled);
    return reconciled;
  }

  ({int current, int longest}) _calculateStreak(
    Map<DateTime, Duration> focusedByDay,
    DateTime today,
  ) {
    final minimum = Duration(minutes: config.streakMinimumDailyTargetMinutes);
    final qualifyingDays = <DateTime>{
      for (final entry in focusedByDay.entries)
        if (entry.value >= minimum) entry.key,
    };

    if (qualifyingDays.isEmpty) {
      return (current: 0, longest: 0);
    }

    final sortedDays = qualifyingDays.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var index = 1; index < sortedDays.length; index += 1) {
      if (_previousDay(sortedDays[index]) == sortedDays[index - 1]) {
        run += 1;
      } else {
        run = 1;
      }
      longest = max(longest, run);
    }

    var current = 0;
    var cursor = qualifyingDays.contains(today) ? today : _previousDay(today);
    while (qualifyingDays.contains(cursor)) {
      current += 1;
      cursor = _previousDay(cursor);
    }

    return (current: current, longest: longest);
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
    final aggregates = _historyAggregates();
    final totalExperience = _profile.totalExperience;
    final finalizedSessions =
        aggregates.completedSessions + aggregates.cancelledSessions;
    final completionRate = finalizedSessions == 0
        ? 0.0
        : aggregates.completedSessions / finalizedSessions * 100;
    final currentLevel = _profile.currentLevel;
    final levelStart = _levelStrategy.experienceForLevel(currentLevel, config);
    final nextLevelStart = _levelStrategy.experienceForLevel(
      currentLevel + 1,
      config,
    );
    final band = nextLevelStart - levelStart;
    final progressToNextLevel = max(0, totalExperience - levelStart);
    final experienceToNextLevel = max(0, nextLevelStart - totalExperience);
    final levelProgress = band <= 0
        ? 1.0
        : min(1.0, progressToNextLevel / band);

    return FocusStatistics(
      focusedToday: aggregates.focusedToday,
      focusedThisWeek: aggregates.focusedThisWeek,
      focusedThisMonth: aggregates.focusedThisMonth,
      totalFocused: _profile.totalFocusedDuration,
      completedSessions: aggregates.completedSessions,
      cancelledSessions: aggregates.cancelledSessions,
      failedSessions: aggregates.failedSessions,
      completionRate: completionRate,
      currentStreak: aggregates.currentStreak,
      longestStreak: aggregates.longestStreak,
      totalPoints: _profile.totalPoints,
      totalExperience: totalExperience,
      currentLevel: currentLevel,
      progressToNextLevel: progressToNextLevel,
      experienceToNextLevel: experienceToNextLevel,
      levelProgress: levelProgress,
    );
  }

  /// Returns history-derived aggregates, recomputing them only when the
  /// history list or the calendar day has changed since the last call.
  _HistoryAggregates _historyAggregates() {
    final today = _dayKey(_clock.now());
    final cached = _aggregates;
    if (cached != null &&
        identical(_aggregatesSource, _sessionHistory) &&
        _aggregatesDay == today) {
      return cached;
    }

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime.utc(today.year, today.month);
    final focusedByDay = <DateTime, Duration>{};
    var focusedToday = Duration.zero;
    var focusedThisWeek = Duration.zero;
    var focusedThisMonth = Duration.zero;
    var completedSessions = 0;
    var cancelledSessions = 0;
    var failedSessions = 0;

    for (final session in _sessionHistory) {
      switch (session.status) {
        case FocusSessionStatus.cancelled:
          cancelledSessions += 1;
        case FocusSessionStatus.failed:
          cancelledSessions += 1;
          failedSessions += 1;
        case FocusSessionStatus.completed:
          completedSessions += 1;
          final completedAt = session.completedAt;
          if (completedAt == null) {
            continue;
          }
          final day = _dayKey(completedAt);
          final focused = session.actualFocusDuration;
          focusedByDay[day] = (focusedByDay[day] ?? Duration.zero) + focused;
          if (day.isAfter(today)) {
            continue;
          }
          if (day == today) {
            focusedToday += focused;
          }
          if (!day.isBefore(weekStart)) {
            focusedThisWeek += focused;
          }
          if (!day.isBefore(monthStart)) {
            focusedThisMonth += focused;
          }
        case FocusSessionStatus.idle:
        case FocusSessionStatus.running:
        case FocusSessionStatus.paused:
          break;
      }
    }

    final streak = _calculateStreak(focusedByDay, today);
    final aggregates = _HistoryAggregates(
      focusedToday: focusedToday,
      focusedThisWeek: focusedThisWeek,
      focusedThisMonth: focusedThisMonth,
      completedSessions: completedSessions,
      cancelledSessions: cancelledSessions,
      failedSessions: failedSessions,
      currentStreak: streak.current,
      longestStreak: streak.longest,
    );
    _aggregates = aggregates;
    _aggregatesSource = _sessionHistory;
    _aggregatesDay = today;
    return aggregates;
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

  /// Local calendar day of [value] as a UTC date, so day arithmetic is exact
  /// across daylight-saving transitions.
  DateTime _dayKey(DateTime value) {
    return DateTime.utc(value.year, value.month, value.day);
  }

  DateTime _previousDay(DateTime dayKey) {
    return dayKey.subtract(const Duration(days: 1));
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
    if (advanced.status != FocusSessionStatus.completed) {
      _activeSession = advanced;
    } else {
      _isCompletingFromTick = true;
      try {
        final before = _progressSnapshot();
        final leveledUp = await _finalizeSession(advanced, completed: true);
        _stopTicker();
        _syncState();
        _publishFinalized(
          FocusSessionCompletedEvent(
            session: advanced,
            occurredAt: _clock.now(),
          ),
          before,
        );
        await _notifyFeedback(_feedback.onSessionCompleted);
        if (leveledUp) {
          await _notifyFeedback(_feedback.onLevelUp);
        }
      } finally {
        _isCompletingFromTick = false;
      }
      return;
    }
    _syncState();
  }

  void _emit(FocusQuestEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  /// Progress values compared before and after a session is finalized to
  /// detect milestones.
  _ProgressSnapshot _progressSnapshot() {
    final aggregates = _historyAggregates();
    return (
      level: _profile.currentLevel,
      streak: aggregates.currentStreak,
      focusedToday: aggregates.focusedToday,
    );
  }

  /// Emits the event for a session that has just been finalized, followed by
  /// any milestones it caused relative to [before].
  void _publishFinalized(FocusSessionEvent event, _ProgressSnapshot before) {
    _emit(event);
    final after = _progressSnapshot();
    final occurredAt = event.occurredAt;
    if (after.level > before.level) {
      _emit(
        FocusLevelUpEvent(
          previousLevel: before.level,
          newLevel: after.level,
          occurredAt: occurredAt,
        ),
      );
    }
    if (after.streak > before.streak) {
      _emit(
        FocusStreakIncreasedEvent(
          previousStreak: before.streak,
          currentStreak: after.streak,
          occurredAt: occurredAt,
        ),
      );
    }
    final goal = config.dailyGoalDuration;
    if (goal > Duration.zero &&
        before.focusedToday < goal &&
        after.focusedToday >= goal) {
      _emit(
        FocusDailyGoalReachedEvent(
          focusedToday: after.focusedToday,
          dailyGoal: goal,
          occurredAt: occurredAt,
        ),
      );
    }
  }

  /// Runs a feedback [hook] without letting its failure affect session state.
  Future<void> _notifyFeedback(Future<void> Function() hook) async {
    try {
      await hook();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'focus_quest',
          context: ErrorDescription('while running a FocusFeedback hook'),
        ),
      );
    }
  }
}

typedef _ProgressSnapshot = ({int level, int streak, Duration focusedToday});

class _HistoryAggregates {
  const _HistoryAggregates({
    required this.focusedToday,
    required this.focusedThisWeek,
    required this.focusedThisMonth,
    required this.completedSessions,
    required this.cancelledSessions,
    required this.failedSessions,
    required this.currentStreak,
    required this.longestStreak,
  });

  final Duration focusedToday;
  final Duration focusedThisWeek;
  final Duration focusedThisMonth;
  final int completedSessions;
  final int cancelledSessions;
  final int failedSessions;
  final int currentStreak;
  final int longestStreak;
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
