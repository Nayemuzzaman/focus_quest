import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  late FakeFocusClock clock;
  late FocusQuestController controller;

  setUp(() async {
    clock = FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10));
    controller = FocusQuestController(
      clock: clock,
      storage: InMemoryFocusQuestStorage(),
      config: const FocusQuestConfig(streakMinimumDailyTargetMinutes: 25),
    );
    await controller.initialize();
  });

  Future<void> completeSessionOn(DateTime start) async {
    clock.setNow(start);
    await controller.start(duration: const Duration(minutes: 25));
    clock.advance(const Duration(minutes: 25));
    await controller.complete();
  }

  test(
    'current streak drops to zero once days pass without sessions',
    () async {
      await completeSessionOn(DateTime(2024, 1, 1, 10));
      expect(controller.state.currentStreak, 1);

      clock.setNow(DateTime(2024, 1, 5, 10));
      await controller.refreshStatistics();

      expect(controller.state.currentStreak, 0);
      expect(controller.state.longestStreak, 1);
    },
  );

  test('current streak is kept while yesterday still qualifies', () async {
    await completeSessionOn(DateTime(2024, 1, 1, 10));

    clock.setNow(DateTime(2024, 1, 2, 9));
    await controller.refreshStatistics();

    expect(controller.state.currentStreak, 1);
  });

  test(
    'restored controller reports the live streak, not the stored one',
    () async {
      final storage = InMemoryFocusQuestStorage();
      controller = FocusQuestController(clock: clock, storage: storage);
      await controller.initialize();
      await completeSessionOn(DateTime(2024, 1, 1, 10));

      final restored = FocusQuestController(
        clock: FakeFocusClock(initialTime: DateTime(2024, 1, 9, 10)),
        storage: storage,
      );
      await restored.initialize();

      expect(restored.state.currentStreak, 0);
      expect(restored.state.longestStreak, 1);
    },
  );

  test('streaks stay continuous across the spring-forward DST day', () async {
    // US DST starts 2024-03-10. Local midnight arithmetic yields a 23h day.
    for (final day in [9, 10, 11]) {
      await completeSessionOn(DateTime(2024, 3, day, 10));
    }

    expect(controller.state.currentStreak, 3);
    expect(controller.state.longestStreak, 3);
  });

  test('streaks stay continuous across the fall-back DST day', () async {
    // US DST ends 2024-11-03. Local midnight arithmetic yields a 25h day.
    for (final day in [2, 3, 4]) {
      await completeSessionOn(DateTime(2024, 11, day, 10));
    }

    expect(controller.state.currentStreak, 3);
    expect(controller.state.longestStreak, 3);
  });
}
