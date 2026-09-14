import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  late FakeFocusClock clock;
  late InMemoryFocusQuestStorage storage;

  setUp(() {
    clock = FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10));
    storage = InMemoryFocusQuestStorage();
  });

  test(
    'failed sessions are counted consistently by profile and statistics',
    () async {
      final controller = FocusQuestController(
        clock: clock,
        storage: storage,
        config: const FocusQuestConfig(
          backgroundBehavior: BackgroundBehavior.keepRunning,
          maxInterruptions: 0,
        ),
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 25));
      await controller.complete();
      await controller.start(duration: const Duration(minutes: 25));
      await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);

      final statistics = controller.state.statistics;
      expect(statistics.completedSessions, 1);
      expect(statistics.failedSessions, 1);
      expect(statistics.cancelledSessions, 1);
      expect(statistics.completionRate, 50);
      expect(controller.profile.cancelledSessions, 1);
    },
  );
}
