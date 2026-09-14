import 'dart:math';

import 'package:focus_quest/src/config/focus_quest_config.dart';

/// Maps accumulated experience to levels.
abstract class LevelStrategy {
  /// Allows subclasses to declare const constructors.
  const LevelStrategy();

  /// Returns the level reached with [experience] total experience.
  int levelForExperience(int experience, FocusQuestConfig config);

  /// Returns the total experience needed to reach [level].
  ///
  /// Level 1 always starts at zero experience.
  int experienceForLevel(int level, FocusQuestConfig config);
}

/// Default level curve: reaching level `n` requires
/// `levelBaseXp * (n - 1) ^ levelExponent` total experience.
class DefaultLevelStrategy implements LevelStrategy {
  /// Creates the default level strategy.
  const DefaultLevelStrategy();

  @override
  int levelForExperience(int experience, FocusQuestConfig config) {
    if (experience <= 0) {
      return 1;
    }
    var level =
        pow(experience / config.levelBaseXp, 1 / config.levelExponent).floor() +
        1;
    // Rounding in experienceForLevel can shift a boundary by one point, so
    // settle on the highest level whose requirement is actually met.
    while (experienceForLevel(level + 1, config) <= experience) {
      level += 1;
    }
    while (level > 1 && experienceForLevel(level, config) > experience) {
      level -= 1;
    }
    return level;
  }

  @override
  int experienceForLevel(int level, FocusQuestConfig config) {
    if (level <= 1) {
      return 0;
    }
    return (config.levelBaseXp * pow(level - 1, config.levelExponent)).round();
  }
}
