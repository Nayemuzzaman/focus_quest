import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  group('FocusQuestController.events', () {
    late FakeFocusClock clock;
    late InMemoryFocusQuestStorage storage;
    late List<FocusQuestEvent> events;
    late FocusQuestController controller;

    // Broadcast streams deliver asynchronously; a zero-delay timer runs after
    // all pending microtasks, so every emitted event has been delivered.
    Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

    FocusQuestController buildController({FocusQuestConfig? config}) {
      final created = FocusQuestController(
        clock: clock,
        storage: storage,
        config: config,
      );
      created.events.listen(events.add);
      return created;
    }

    List<Type> sessionEventTypes() => events
        .whereType<FocusSessionEvent>()
        .map((event) => event.runtimeType)
        .toList();

    setUp(() {
      clock = FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10));
      storage = InMemoryFocusQuestStorage();
      events = <FocusQuestEvent>[];
      controller = buildController();
    });

    test('emits start, pause, resume, and complete in order', () async {
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 5));
      await controller.pause();
      await controller.resume();
      clock.advance(const Duration(minutes: 20));
      await controller.complete();
      await flushEvents();

      expect(sessionEventTypes(), [
        FocusSessionStartedEvent,
        FocusSessionPausedEvent,
        FocusSessionResumedEvent,
        FocusSessionCompletedEvent,
      ]);
      final ids = events
          .whereType<FocusSessionEvent>()
          .map((event) => event.session.id)
          .toSet();
      expect(ids, hasLength(1));

      final completed = events.whereType<FocusSessionCompletedEvent>().single;
      expect(completed.session.status, FocusSessionStatus.completed);
      expect(completed.session.reward?.points, 35);
      expect(completed.completedWhileAway, isFalse);
      expect(completed.occurredAt, clock.now());
    });

    test('emits a cancelled event carrying the reason', () async {
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 10));
      await controller.cancel(reason: 'Stopped early');
      await flushEvents();

      final cancelled = events.whereType<FocusSessionCancelledEvent>().single;
      expect(cancelled.session.status, FocusSessionStatus.cancelled);
      expect(cancelled.session.failureReason, 'Stopped early');
    });

    test('reset emits cancelled only when a session was active', () async {
      await controller.initialize();
      await controller.reset();
      await flushEvents();
      expect(events, isEmpty);

      await controller.start(duration: const Duration(minutes: 25));
      await controller.reset();
      await flushEvents();

      expect(sessionEventTypes(), [
        FocusSessionStartedEvent,
        FocusSessionCancelledEvent,
      ]);
      expect(
        events
            .whereType<FocusSessionCancelledEvent>()
            .single
            .session
            .failureReason,
        'Session reset.',
      );
    });

    test('emits failed when interruptions exceed the maximum', () async {
      controller = buildController(
        config: const FocusQuestConfig(maxInterruptions: 0),
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);
      await flushEvents();

      expect(sessionEventTypes(), [
        FocusSessionStartedEvent,
        FocusSessionFailedEvent,
      ]);
      expect(
        events.whereType<FocusSessionFailedEvent>().single.session.status,
        FocusSessionStatus.failed,
      );
    });

    test('emits paused when backgrounding pauses the session', () async {
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);
      await flushEvents();

      final paused = events.whereType<FocusSessionPausedEvent>().single;
      expect(paused.session.interruptionCount, 1);
    });

    test('emits nothing when start is rejected', () async {
      await controller.initialize();
      await expectLater(
        () => controller.start(duration: Duration.zero),
        throwsA(isA<FocusQuestException>()),
      );
      await flushEvents();

      expect(events, isEmpty);
    });

    test('emits completed when the ticker finishes the session', () async {
      await controller.initialize();
      await controller.start(duration: const Duration(seconds: 1));
      clock.advance(const Duration(seconds: 2));

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await flushEvents();

      expect(events.whereType<FocusSessionCompletedEvent>(), hasLength(1));
    });

    test('listeners observe the already-published state', () async {
      FocusSessionStatus? statusSeen;
      int? completedSeen;
      controller.events.listen((event) {
        if (event is FocusSessionCompletedEvent) {
          statusSeen = controller.state.status;
          completedSeen = controller.state.statistics.completedSessions;
        }
      });

      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 25));
      await controller.complete();
      await flushEvents();

      expect(statusSeen, FocusSessionStatus.idle);
      expect(completedSeen, 1);
    });

    test('delivers every event to every subscriber', () async {
      final second = <FocusQuestEvent>[];
      controller.events.listen(second.add);

      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      await flushEvents();

      expect(events.whereType<FocusSessionStartedEvent>(), hasLength(1));
      expect(second.whereType<FocusSessionStartedEvent>(), hasLength(1));
    });

    test('dispose closes the stream', () async {
      await controller.initialize();
      final done = expectLater(controller.events, emitsDone);

      controller.dispose();

      await done;
    });

    test('emits level-up after the completed event', () async {
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 120));
      clock.advance(const Duration(minutes: 120));
      await controller.complete();
      await flushEvents();

      final levelUp = events.whereType<FocusLevelUpEvent>().single;
      expect(levelUp.previousLevel, 1);
      expect(levelUp.newLevel, 2);
      expect(
        events.indexOf(levelUp),
        greaterThan(
          events.indexWhere((event) => event is FocusSessionCompletedEvent),
        ),
      );
    });

    test('does not emit level-up when the level is unchanged', () async {
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 25));
      await controller.complete();
      await flushEvents();

      expect(events.whereType<FocusLevelUpEvent>(), isEmpty);
    });

    test('emits streak increases once per new qualifying day', () async {
      Future<void> focus(Duration duration) async {
        await controller.start(duration: duration);
        clock.advance(duration);
        await controller.complete();
      }

      await controller.initialize();
      await focus(const Duration(minutes: 25));
      await focus(const Duration(minutes: 25));
      clock.setNow(DateTime(2024, 1, 2, 10));
      await focus(const Duration(minutes: 25));
      await flushEvents();

      final streaks = events.whereType<FocusStreakIncreasedEvent>().toList();
      expect(
        streaks.map((event) => (event.previousStreak, event.currentStreak)),
        [(0, 1), (1, 2)],
      );
    });

    test('emits daily goal reached only for the crossing session', () async {
      controller = buildController(
        config: const FocusQuestConfig(
          dailyGoalDuration: Duration(minutes: 30),
        ),
      );
      Future<void> focus(Duration duration) async {
        await controller.start(duration: duration);
        clock.advance(duration);
        await controller.complete();
      }

      await controller.initialize();
      await focus(const Duration(minutes: 25));
      await flushEvents();
      expect(events.whereType<FocusDailyGoalReachedEvent>(), isEmpty);

      await focus(const Duration(minutes: 10));
      await focus(const Duration(minutes: 10));
      await flushEvents();

      final goal = events.whereType<FocusDailyGoalReachedEvent>().single;
      expect(goal.focusedToday, const Duration(minutes: 35));
      expect(goal.dailyGoal, const Duration(minutes: 30));
    });

    test('does not emit milestones for a failed session', () async {
      controller = buildController(
        config: const FocusQuestConfig(maxInterruptions: 0),
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 25));
      await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);
      await flushEvents();

      expect(events.whereType<FocusLevelUpEvent>(), isEmpty);
      expect(events.whereType<FocusStreakIncreasedEvent>(), isEmpty);
      expect(events.whereType<FocusDailyGoalReachedEvent>(), isEmpty);
    });

    test(
      'a subscriber attached before initialize receives a restored completion',
      () async {
        await controller.initialize();
        await controller.start(duration: const Duration(minutes: 25));
        controller.dispose();

        clock.advance(const Duration(hours: 1));
        final restoredEvents = <FocusQuestEvent>[];
        final restored = FocusQuestController(clock: clock, storage: storage);
        restored.events.listen(restoredEvents.add);
        await restored.initialize();
        await flushEvents();

        final completed = restoredEvents
            .whereType<FocusSessionCompletedEvent>()
            .single;
        expect(completed.completedWhileAway, isTrue);
        expect(completed.session.completedAt, DateTime(2024, 1, 1, 10, 25));
        expect(completed.occurredAt, DateTime(2024, 1, 1, 11));
        expect(
          restoredEvents
              .whereType<FocusStreakIncreasedEvent>()
              .single
              .currentStreak,
          1,
        );
      },
    );

    test(
      'a restored session from a previous day does not reach today\'s goal',
      () async {
        const config = FocusQuestConfig(
          dailyGoalDuration: Duration(minutes: 25),
        );
        clock.setNow(DateTime(2024, 1, 1, 23));
        controller = buildController(config: config);
        await controller.initialize();
        await controller.start(duration: const Duration(minutes: 25));
        controller.dispose();

        clock.setNow(DateTime(2024, 1, 2, 9));
        final restoredEvents = <FocusQuestEvent>[];
        final restored = FocusQuestController(
          clock: clock,
          storage: storage,
          config: config,
        );
        restored.events.listen(restoredEvents.add);
        await restored.initialize();
        await flushEvents();

        expect(
          restoredEvents
              .whereType<FocusSessionCompletedEvent>()
              .single
              .completedWhileAway,
          isTrue,
        );
        expect(restoredEvents.whereType<FocusDailyGoalReachedEvent>(), isEmpty);
      },
    );
  });
}
