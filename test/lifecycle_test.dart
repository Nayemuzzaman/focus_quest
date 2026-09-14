import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  late FakeFocusClock clock;
  late InMemoryFocusQuestStorage storage;

  setUp(() {
    clock = FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10));
    storage = InMemoryFocusQuestStorage();
  });

  FocusQuestController buildController({
    BackgroundBehavior behavior = BackgroundBehavior.pause,
    int maxInterruptions = 3,
    FocusLifecycleHandler? handler,
  }) {
    return FocusQuestController(
      clock: clock,
      storage: storage,
      lifecycleHandler: handler,
      config: FocusQuestConfig(
        backgroundBehavior: behavior,
        maxInterruptions: maxInterruptions,
      ),
    );
  }

  group('handleLifecycleEvent', () {
    test(
      'a paused event while the session is already paused is ignored',
      () async {
        final controller = buildController();
        await controller.initialize();
        await controller.start(duration: const Duration(minutes: 25));

        await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);
        await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);

        expect(controller.state.status, FocusSessionStatus.paused);
        expect(controller.state.activeSession?.interruptionCount, 1);
      },
    );

    test('a paused event after the user paused does not count', () async {
      final controller = buildController();
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      await controller.pause();

      await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);

      expect(controller.state.activeSession?.interruptionCount, 0);
      expect(controller.state.status, FocusSessionStatus.paused);
    });

    test('an inactive event leaves a running session untouched', () async {
      final controller = buildController();
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));

      await controller.handleLifecycleEvent(FocusLifecycleEvent.inactive);

      expect(controller.state.status, FocusSessionStatus.running);
      expect(controller.state.activeSession?.interruptionCount, 0);
    });

    test('a detached event applies the background behavior', () async {
      final controller = buildController(behavior: BackgroundBehavior.cancel);
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));

      await controller.handleLifecycleEvent(FocusLifecycleEvent.detached);

      expect(controller.state.status, FocusSessionStatus.idle);
      expect(
        controller.state.sessionHistory.single.status,
        FocusSessionStatus.cancelled,
      );
    });

    test('keepRunning records the interruption and syncs state', () async {
      final controller = buildController(
        behavior: BackgroundBehavior.keepRunning,
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));

      await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);

      expect(controller.state.status, FocusSessionStatus.running);
      expect(controller.state.activeSession?.interruptionCount, 1);
    });

    test('every event is forwarded to the lifecycle handler', () async {
      final received = <FocusLifecycleEvent>[];
      final controller = buildController(
        handler: FocusLifecycleBridge((event) async => received.add(event)),
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));

      for (final event in FocusLifecycleEvent.values) {
        await controller.handleLifecycleEvent(event);
      }

      expect(received, FocusLifecycleEvent.values);
    });
  });
}
