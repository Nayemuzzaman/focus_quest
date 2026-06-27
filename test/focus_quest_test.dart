import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FocusQuestController', () {
    late FakeFocusClock clock;
    late InMemoryFocusQuestStorage storage;
    late FocusQuestController controller;

    setUp(() {
      clock = FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10));
      storage = InMemoryFocusQuestStorage();
      controller = FocusQuestController(clock: clock, storage: storage);
    });

    test('starts in an idle initialized state', () async {
      await controller.initialize();

      expect(controller.state.status, FocusSessionStatus.idle);
      expect(controller.state.remainingDuration, Duration.zero);
      expect(controller.state.statistics.completedSessions, 0);
      expect(controller.state.error, isNull);
    });

    test(
      'starts a session with metadata and rejects duplicate starts',
      () async {
        await controller.initialize();
        await controller.start(
          duration: const Duration(minutes: 25),
          metadata: {'category': 'study'},
        );

        expect(controller.state.status, FocusSessionStatus.running);
        expect(controller.state.activeSession?.metadata['category'], 'study');
        expect(
          () => controller.start(duration: const Duration(minutes: 5)),
          throwsA(isA<FocusQuestException>()),
        );
      },
    );

    test('pauses, resumes, and keeps timestamp-based elapsed time', () async {
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));

      clock.advance(const Duration(minutes: 10));
      await controller.pause();
      expect(controller.state.status, FocusSessionStatus.paused);
      expect(
        controller.state.elapsedFocusDuration,
        const Duration(minutes: 10),
      );

      clock.advance(const Duration(minutes: 5));
      await controller.resume();
      clock.advance(const Duration(minutes: 3));
      await controller.pause();

      expect(
        controller.state.elapsedFocusDuration,
        const Duration(minutes: 13),
      );
      expect(controller.state.remainingDuration, const Duration(minutes: 12));
      expect(controller.state.activeSession?.pauseCount, 2);
    });

    test(
      'completes once and awards completion points and experience',
      () async {
        await controller.initialize();
        await controller.start(duration: const Duration(minutes: 25));
        clock.advance(const Duration(minutes: 25));

        await controller.complete();

        expect(controller.state.status, FocusSessionStatus.idle);
        expect(controller.state.statistics.completedSessions, 1);
        expect(controller.state.statistics.cancelledSessions, 0);
        expect(controller.state.statistics.totalPoints, 35);
        expect(controller.state.statistics.totalExperience, 35);
        expect(controller.state.sessionHistory.single.reward?.metadata, {
          'completed': true,
          'partial': false,
        });
        expect(controller.complete, throwsA(isA<FocusQuestException>()));
      },
    );

    test(
      'ticker refreshes from timestamps and completes automatically',
      () async {
        await controller.initialize();
        await controller.start(duration: const Duration(seconds: 1));
        clock.advance(const Duration(seconds: 2));

        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(controller.state.status, FocusSessionStatus.idle);
        expect(controller.state.statistics.completedSessions, 1);
        expect(controller.state.sessionHistory.single.reward?.points, 10);
      },
    );

    test('cancels with optional partial rewards', () async {
      controller = FocusQuestController(
        clock: clock,
        storage: storage,
        config: const FocusQuestConfig(partialRewardMultiplier: 0.5),
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 10));

      await controller.cancel(reason: 'Stopped early');

      final session = controller.state.sessionHistory.single;
      expect(session.status, FocusSessionStatus.cancelled);
      expect(session.failureReason, 'Stopped early');
      expect(session.reward?.points, 5);
      expect(controller.state.statistics.cancelledSessions, 1);
      expect(controller.state.statistics.completionRate, 0);
    });

    test('disables partial rewards when configured', () async {
      controller = FocusQuestController(
        clock: clock,
        storage: storage,
        config: const FocusQuestConfig(partialRewardEnabled: false),
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 10));

      await controller.cancel();

      expect(controller.state.statistics.totalPoints, 0);
      expect(controller.state.sessionHistory.single.reward?.experience, 0);
    });

    test('rejects invalid state transitions', () async {
      await controller.initialize();

      expect(controller.pause, throwsA(isA<FocusQuestException>()));
      await controller.start(duration: const Duration(minutes: 25));
      expect(controller.resume, throwsA(isA<FocusQuestException>()));
      await controller.pause();
      expect(controller.pause, throwsA(isA<FocusQuestException>()));
    });

    test(
      'reset finalizes active persisted sessions so they do not restore',
      () async {
        await controller.initialize();
        await controller.start(duration: const Duration(minutes: 25));
        clock.advance(const Duration(minutes: 5));

        await controller.reset();

        final restoredController = FocusQuestController(
          clock: FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10, 10)),
          storage: storage,
        );
        await restoredController.initialize();

        expect(restoredController.state.status, FocusSessionStatus.idle);
        expect(
          restoredController.state.sessionHistory.single.status,
          FocusSessionStatus.cancelled,
        );
        expect(
          restoredController.state.sessionHistory.single.failureReason,
          'Session reset.',
        );
      },
    );

    test('restores and finalizes an active session after restart', () async {
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 30));

      final restoredController = FocusQuestController(
        clock: FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10, 45)),
        storage: storage,
      );
      await restoredController.initialize();

      expect(restoredController.state.status, FocusSessionStatus.idle);
      expect(restoredController.state.statistics.completedSessions, 1);
      expect(
        restoredController.state.sessionHistory.single.status,
        FocusSessionStatus.completed,
      );
    });

    test(
      'tracks background lifecycle interruptions and pause behavior',
      () async {
        controller = FocusQuestController(
          clock: clock,
          storage: storage,
          config: const FocusQuestConfig(
            backgroundBehavior: BackgroundBehavior.pause,
            maxInterruptions: 2,
          ),
        );
        await controller.initialize();
        await controller.start(duration: const Duration(minutes: 25));

        await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);

        expect(controller.state.status, FocusSessionStatus.paused);
        expect(controller.state.activeSession?.interruptionCount, 1);
      },
    );

    test('fails the session after too many lifecycle interruptions', () async {
      controller = FocusQuestController(
        clock: clock,
        storage: storage,
        config: const FocusQuestConfig(
          backgroundBehavior: BackgroundBehavior.keepRunning,
          maxInterruptions: 0,
        ),
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));

      await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);

      expect(controller.state.status, FocusSessionStatus.idle);
      expect(
        controller.state.sessionHistory.single.status,
        FocusSessionStatus.failed,
      );
      expect(
        controller.state.sessionHistory.single.failureReason,
        'Maximum interruptions exceeded.',
      );
    });

    test('calculates daily goal progress and same-day streaks', () async {
      controller = FocusQuestController(
        clock: clock,
        storage: storage,
        config: const FocusQuestConfig(
          dailyGoalDuration: Duration(minutes: 50),
          streakMinimumDailyTargetMinutes: 25,
        ),
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 25));
      await controller.complete();

      expect(controller.state.focusedToday, const Duration(minutes: 25));
      expect(controller.state.dailyGoalProgress, 0.5);
      expect(controller.state.currentStreak, 1);
      expect(controller.state.longestStreak, 1);
    });

    test('calculates consecutive and missed-day streaks', () async {
      controller = FocusQuestController(
        clock: clock,
        storage: storage,
        config: const FocusQuestConfig(streakMinimumDailyTargetMinutes: 25),
      );
      await controller.initialize();

      for (final day in [1, 2, 4]) {
        clock.setNow(DateTime(2024, 1, day, 10));
        await controller.start(duration: const Duration(minutes: 25));
        clock.advance(const Duration(minutes: 25));
        await controller.complete();
      }

      expect(controller.state.currentStreak, 1);
      expect(controller.state.longestStreak, 2);
    });

    test(
      'clearError clears initialization errors from failed storage',
      () async {
        controller = FocusQuestController(storage: _FailingStorage());

        await controller.initialize();
        expect(controller.state.error, isNotNull);

        await controller.clearError();
        expect(controller.state.error, isNull);
      },
    );
  });

  group('storage and serialization', () {
    test('in-memory storage saves, replaces, and clears data', () async {
      final storage = InMemoryFocusQuestStorage();
      final session = FocusSession(
        id: 'one',
        startedAt: DateTime(2024),
        targetDuration: const Duration(minutes: 5),
      );

      await storage.initialize();
      await storage.saveSession(session);
      await storage.saveSession(
        session.copyWith(status: FocusSessionStatus.completed),
      );
      await storage.saveProfile(const FocusProfile(totalPoints: 10));

      expect(
        (await storage.loadSessions()).single.status,
        FocusSessionStatus.completed,
      );
      expect((await storage.loadProfile())?.totalPoints, 10);

      await storage.clear();
      expect(await storage.loadSessions(), isEmpty);
      expect(await storage.loadProfile(), isNull);
    });

    test('SharedPreferences storage persists sessions and profiles', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SharedPreferencesFocusQuestStorage(prefix: 'test_focus');
      final session = FocusSession(
        id: 'persisted',
        startedAt: DateTime(2024),
        targetDuration: const Duration(minutes: 5),
        metadata: {'task': 'vocabulary'},
      );

      await storage.initialize();
      await storage.saveSession(session);
      await storage.saveProfile(const FocusProfile(totalExperience: 42));

      final reloaded = SharedPreferencesFocusQuestStorage(prefix: 'test_focus');
      await reloaded.initialize();

      expect(
        (await reloaded.loadSessions()).single.metadata['task'],
        'vocabulary',
      );
      expect((await reloaded.loadProfile())?.totalExperience, 42);
    });

    test('Hive storage saves, replaces, reloads, and clears data', () async {
      final directory = await Directory.systemTemp.createTemp(
        'focus_quest_hive_test',
      );
      final boxName =
          'focus_quest_test_${DateTime.now().microsecondsSinceEpoch}';
      try {
        Hive.init(directory.path);
        final storage = HiveFocusQuestStorage(
          boxName: boxName,
          initializeHive: false,
        );
        final session = FocusSession(
          id: 'hive-session',
          startedAt: DateTime(2024),
          targetDuration: const Duration(minutes: 5),
          metadata: {'category': 'offline'},
        );

        await storage.initialize();
        await storage.saveSession(session);
        await storage.saveSession(
          session.copyWith(status: FocusSessionStatus.completed),
        );
        await storage.saveProfile(const FocusProfile(totalPoints: 20));

        final reloaded = HiveFocusQuestStorage(
          boxName: boxName,
          initializeHive: false,
        );
        await reloaded.initialize();

        expect(
          (await reloaded.loadSessions()).single.status,
          FocusSessionStatus.completed,
        );
        expect(
          (await reloaded.loadSessions()).single.metadata['category'],
          'offline',
        );
        expect((await reloaded.loadProfile())?.totalPoints, 20);

        await reloaded.clear();
        expect(await reloaded.loadSessions(), isEmpty);
        expect(await reloaded.loadProfile(), isNull);
      } finally {
        await Hive.deleteBoxFromDisk(boxName, path: directory.path);
        await Hive.close();
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      }
    });
  });

  group('feedback', () {
    test(
      'audioplayers feedback is a no-op when no assets are configured',
      () async {
        final feedback = AudioplayersFocusFeedback();

        await feedback.onSessionStarted();
        await feedback.onSessionPaused();
        await feedback.onSessionResumed();
        await feedback.onSessionCompleted();
        await feedback.onSessionCancelled();
        await feedback.onLevelUp();
        await feedback.dispose();
      },
    );
  });

  group('Riverpod integration', () {
    test('notifier coordinates controller actions', () async {
      final controller = FocusQuestController(
        clock: FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10)),
        storage: InMemoryFocusQuestStorage(),
      );
      final container = ProviderContainer(
        overrides: [focusQuestControllerProvider.overrideWithValue(controller)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(focusQuestStateProvider.notifier);
      await notifier.initialize();
      await notifier.start(duration: const Duration(minutes: 5));
      await notifier.pause();
      await notifier.resume();
      await notifier.cancel(reason: 'Riverpod test');

      final state = container.read(focusQuestStateProvider);
      expect(state.sessionHistory.single.failureReason, 'Riverpod test');
      expect(state.status, FocusSessionStatus.idle);
    });
  });
}

class _FailingStorage implements FocusQuestStorage {
  @override
  Future<void> initialize() async {
    throw StateError('storage unavailable');
  }

  @override
  Future<void> clear() async {}

  @override
  Future<FocusProfile?> loadProfile() async => null;

  @override
  Future<List<FocusSession>> loadSessions() async => <FocusSession>[];

  @override
  Future<void> saveProfile(FocusProfile profile) async {}

  @override
  Future<void> saveSession(FocusSession session) async {}
}
