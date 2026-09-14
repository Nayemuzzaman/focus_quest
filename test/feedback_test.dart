import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  late FakeFocusClock clock;

  setUp(() {
    clock = FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10));
  });

  test(
    'a throwing feedback implementation does not break the session',
    () async {
      final reported = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previousHandler);
      final controller = FocusQuestController(
        clock: clock,
        storage: InMemoryFocusQuestStorage(),
        feedback: const _ThrowingFeedback(),
      );
      await controller.initialize();

      await controller.start(duration: const Duration(minutes: 25));
      expect(controller.state.status, FocusSessionStatus.running);

      clock.advance(const Duration(minutes: 25));
      await controller.complete();
      expect(controller.state.status, FocusSessionStatus.idle);
      expect(controller.state.statistics.completedSessions, 1);
      expect(reported.map((details) => details.library), [
        'focus_quest',
        'focus_quest',
      ]);
    },
  );

  test('state is published before feedback hooks run', () async {
    final observed = <FocusSessionStatus>[];
    final controller = FocusQuestController(
      clock: clock,
      storage: InMemoryFocusQuestStorage(),
      feedback: _ProbeFeedback(() => observed),
    );
    _ProbeFeedback.controller = controller;
    await controller.initialize();

    await controller.start(duration: const Duration(minutes: 25));
    await controller.pause();

    expect(observed, [FocusSessionStatus.running, FocusSessionStatus.paused]);
  });

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
}

class _ThrowingFeedback extends NoopFocusFeedback {
  const _ThrowingFeedback();

  @override
  Future<void> onSessionStarted() async => throw StateError('no haptics');

  @override
  Future<void> onSessionCompleted() => Future.error(StateError('no audio'));
}

class _ProbeFeedback extends NoopFocusFeedback {
  _ProbeFeedback(this.sink);

  static late FocusQuestController controller;
  final List<FocusSessionStatus> Function() sink;

  @override
  Future<void> onSessionStarted() async => sink().add(controller.state.status);

  @override
  Future<void> onSessionPaused() async => sink().add(controller.state.status);
}
