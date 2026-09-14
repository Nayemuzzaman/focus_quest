import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  const config = FocusQuestConfig(levelBaseXp: 100, levelExponent: 1.2);

  group('DefaultLevelStrategy', () {
    const strategy = DefaultLevelStrategy();

    test('experience required grows as base * (level - 1) ^ exponent', () {
      expect(strategy.experienceForLevel(1, config), 0);
      expect(strategy.experienceForLevel(2, config), 100);
      expect(strategy.experienceForLevel(3, config), 230);
      expect(strategy.experienceForLevel(5, config), 528);
      expect(strategy.experienceForLevel(10, config), 1397);
    });

    test('level for experience is the inverse of experience for level', () {
      expect(strategy.levelForExperience(0, config), 1);
      expect(strategy.levelForExperience(99, config), 1);
      expect(strategy.levelForExperience(100, config), 2);
      expect(strategy.levelForExperience(229, config), 2);
      expect(strategy.levelForExperience(230, config), 3);
      expect(strategy.levelForExperience(1397, config), 10);
      for (var level = 1; level <= 50; level += 1) {
        final xp = strategy.experienceForLevel(level, config);
        expect(strategy.levelForExperience(xp, config), level);
        expect(
          strategy.levelForExperience(xp - 1, config),
          level - 1 < 1 ? 1 : level - 1,
        );
      }
    });
  });

  group('FocusQuestConfig validation', () {
    test('rejects non-positive level parameters', () {
      expect(() => FocusQuestConfig(levelBaseXp: 0), throwsAssertionError);
      expect(() => FocusQuestConfig(levelExponent: 0), throwsAssertionError);
      expect(() => FocusQuestConfig(levelExponent: -1), throwsAssertionError);
    });

    test('rejects negative reward and interruption values', () {
      expect(
        () => FocusQuestConfig(pointsPerFocusedMinute: -1),
        throwsAssertionError,
      );
      expect(() => FocusQuestConfig(completionBonus: -1), throwsAssertionError);
      expect(
        () => FocusQuestConfig(maxInterruptions: -1),
        throwsAssertionError,
      );
      expect(
        () => FocusQuestConfig(partialRewardMultiplier: -0.1),
        throwsAssertionError,
      );
      expect(
        () => FocusQuestConfig(streakMinimumDailyTargetMinutes: -1),
        throwsAssertionError,
      );
    });
  });

  group('controller levels', () {
    late FakeFocusClock clock;
    late InMemoryFocusQuestStorage storage;

    setUp(() {
      clock = FakeFocusClock(initialTime: DateTime(2024, 1, 1, 10));
      storage = InMemoryFocusQuestStorage();
    });

    Future<FocusQuestController> controllerWithExperience(
      int experience,
    ) async {
      await storage.saveProfile(FocusProfile(totalExperience: experience));
      final controller = FocusQuestController(clock: clock, storage: storage);
      await controller.initialize();
      return controller;
    }

    test('statistics expose a consistent level band', () async {
      // 150 XP: level 2 spans 100..230, so 50 in, 80 to go.
      final controller = await controllerWithExperience(150);

      final statistics = controller.state.statistics;
      expect(statistics.currentLevel, 2);
      expect(statistics.progressToNextLevel, 50);
      expect(statistics.experienceToNextLevel, 80);
      expect(statistics.levelProgress, closeTo(50 / 130, 1e-9));
    });

    test(
      'stored levels from older formulas are recomputed on initialize',
      () async {
        await storage.saveProfile(
          const FocusProfile(totalExperience: 150, currentLevel: 3),
        );
        final controller = FocusQuestController(clock: clock, storage: storage);
        await controller.initialize();

        expect(controller.state.currentLevel, 2);
        expect((await storage.loadProfile())?.currentLevel, 2);
      },
    );

    test(
      'onLevelUp fires once when a session crosses a level boundary',
      () async {
        final feedback = _RecordingFeedback();
        // 70 XP + one 25 minute session (35 XP) = 105 XP -> level 2.
        await storage.saveProfile(const FocusProfile(totalExperience: 70));
        final controller = FocusQuestController(
          clock: clock,
          storage: storage,
          feedback: feedback,
        );
        await controller.initialize();

        await controller.start(duration: const Duration(minutes: 25));
        clock.advance(const Duration(minutes: 25));
        await controller.complete();

        expect(controller.state.currentLevel, 2);
        expect(feedback.levelUps, 1);
        expect(feedback.events, ['completed', 'levelUp']);
      },
    );

    test('onLevelUp does not fire when the level is unchanged', () async {
      final feedback = _RecordingFeedback();
      final controller = FocusQuestController(
        clock: clock,
        storage: storage,
        feedback: feedback,
      );
      await controller.initialize();

      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 25));
      await controller.complete();

      expect(controller.state.currentLevel, 1);
      expect(feedback.levelUps, 0);
    });

    test('a custom level strategy replaces the default curve', () async {
      final controller = FocusQuestController(
        clock: clock,
        storage: storage,
        levelStrategy: const _FlatLevelStrategy(),
      );
      await controller.initialize();

      await controller.start(duration: const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 25));
      await controller.complete();

      // 35 XP with 10 XP per level.
      expect(controller.state.currentLevel, 4);
      expect(controller.state.statistics.progressToNextLevel, 5);
      expect(controller.state.statistics.experienceToNextLevel, 5);
    });
  });
}

class _RecordingFeedback extends NoopFocusFeedback {
  final List<String> events = [];
  int get levelUps => events.where((event) => event == 'levelUp').length;

  @override
  Future<void> onSessionCompleted() async => events.add('completed');

  @override
  Future<void> onLevelUp() async => events.add('levelUp');
}

class _FlatLevelStrategy implements LevelStrategy {
  const _FlatLevelStrategy();

  @override
  int experienceForLevel(int level, FocusQuestConfig config) =>
      (level - 1) * 10;

  @override
  int levelForExperience(int experience, FocusQuestConfig config) =>
      experience ~/ 10 + 1;
}
