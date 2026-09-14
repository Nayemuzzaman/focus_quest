import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  late InMemoryFocusQuestStorage storage;

  setUp(() {
    storage = InMemoryFocusQuestStorage();
  });

  group('restoring a running session', () {
    test('completes at the target, not at restart time', () async {
      final controller = FocusQuestController(
        clock: FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10)),
        storage: storage,
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));

      // The process was killed; the user returns six hours later.
      final restored = FocusQuestController(
        clock: FakeFocusClock(initialTime: DateTime(2024, 1, 1, 16)),
        storage: storage,
      );
      await restored.initialize();

      final session = restored.state.sessionHistory.single;
      expect(session.status, FocusSessionStatus.completed);
      expect(session.actualFocusDuration, const Duration(minutes: 25));
      expect(session.completedAt, DateTime(2024, 1, 1, 10, 25));
      expect(session.reward?.points, 35);
      expect(restored.profile.lastCompletedDate, DateTime(2024, 1, 1));
    });

    test('attributes the session to the day the target was reached', () async {
      final controller = FocusQuestController(
        clock: FakeFocusClock(initialTime: DateTime(2024, 1, 1, 23, 50)),
        storage: storage,
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 30));

      final restored = FocusQuestController(
        clock: FakeFocusClock(initialTime: DateTime(2024, 1, 2, 12)),
        storage: storage,
      );
      await restored.initialize();

      expect(restored.state.focusedToday, const Duration(minutes: 30));
      expect(
        restored.state.sessionHistory.single.completedAt,
        DateTime(2024, 1, 2, 0, 20),
      );
    });
  });

  test('ticker completion clamps focused time to the target', () async {
    final clock = FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10));
    final controller = FocusQuestController(clock: clock, storage: storage);
    await controller.initialize();
    await controller.start(duration: const Duration(seconds: 1));
    clock.advance(const Duration(seconds: 5));

    await Future<void>.delayed(const Duration(milliseconds: 1100));

    final session = controller.state.sessionHistory.single;
    expect(session.status, FocusSessionStatus.completed);
    expect(session.actualFocusDuration, const Duration(seconds: 1));
  });

  group('start', () {
    test('rejects non-positive durations', () async {
      final controller = FocusQuestController(storage: storage);
      await controller.initialize();

      await expectLater(
        () => controller.start(duration: Duration.zero),
        throwsA(isA<FocusQuestException>()),
      );
      await expectLater(
        () => controller.start(duration: const Duration(seconds: -1)),
        throwsA(isA<FocusQuestException>()),
      );
      expect(controller.state.status, FocusSessionStatus.idle);
      expect(controller.activeSession, isNull);
    });

    test('leaves no active session when persistence fails', () async {
      final flaky = _FlakyStorage();
      final controller = FocusQuestController(storage: flaky);
      await controller.initialize();

      flaky.failNextSave = true;
      await expectLater(
        () => controller.start(duration: const Duration(minutes: 5)),
        throwsA(isA<StateError>()),
      );

      expect(controller.activeSession, isNull);
      expect(controller.state.status, FocusSessionStatus.idle);

      await controller.start(duration: const Duration(minutes: 5));
      expect(controller.state.status, FocusSessionStatus.running);
    });
  });
}

class _FlakyStorage extends InMemoryFocusQuestStorage {
  bool failNextSave = false;

  @override
  Future<void> saveSession(FocusSession session) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('disk full');
    }
    await super.saveSession(session);
  }
}
