import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  test('the default controller is disposed with its container', () async {
    final container = ProviderContainer();
    final controller = container.read(focusQuestControllerProvider);

    container.dispose();

    expect(() => controller.addListener(() {}), throwsFlutterError);
  });

  test(
    'the initialization provider initializes the shared controller',
    () async {
      final reported = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previousHandler);
      final container = ProviderContainer(
        overrides: [
          focusQuestControllerProvider.overrideWith(
            (ref) => FocusQuestController(
              clock: FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10)),
              storage: InMemoryFocusQuestStorage(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(focusQuestInitializationProvider.future);
      final notifier = container.read(focusQuestStateProvider.notifier);
      await notifier.start(duration: const Duration(minutes: 5));

      expect(notifier.controller.isInitialized, isTrue);
      expect(
        container.read(focusQuestStateProvider).status,
        FocusSessionStatus.running,
      );
      expect(reported, isEmpty);
    },
  );

  test('the initialization provider surfaces storage failures', () async {
    final container = ProviderContainer(
      overrides: [
        focusQuestControllerProvider.overrideWith(
          (ref) => FocusQuestController(storage: _FailingStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(focusQuestInitializationProvider.future),
      throwsA(isA<FocusQuestException>()),
    );
  });
}

class _FailingStorage extends InMemoryFocusQuestStorage {
  @override
  Future<void> initialize() async {
    throw StateError('storage unavailable');
  }
}
