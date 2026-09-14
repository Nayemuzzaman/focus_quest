import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  group('FocusQuestLifecycleObserver', () {
    test('maps app lifecycle states to controller events', () async {
      final controller = FocusQuestController(
        clock: FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10)),
        storage: InMemoryFocusQuestStorage(),
      );
      await controller.initialize();
      await controller.start(duration: const Duration(minutes: 25));
      final observer = FocusQuestLifecycleObserver(controller);

      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.value();
      expect(controller.state.status, FocusSessionStatus.running);

      observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, FocusSessionStatus.paused);
      expect(controller.state.activeSession?.interruptionCount, 1);
    });
  });
}
