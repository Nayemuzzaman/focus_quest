import 'dart:math';

import 'package:focus_quest/src/config/focus_quest_config.dart';
import 'package:focus_quest/src/models/focus_reward.dart';
import 'package:focus_quest/src/models/focus_session.dart';

abstract class RewardStrategy {
  FocusReward calculate(FocusSession session, FocusQuestConfig config);
}

class DefaultRewardStrategy implements RewardStrategy {
  const DefaultRewardStrategy();

  @override
  FocusReward calculate(FocusSession session, FocusQuestConfig config) {
    final focusedMinutes = max(0, session.actualFocusDuration.inSeconds) ~/ 60;
    final completed = session.status == FocusSessionStatus.completed;
    if (!completed && !config.partialRewardEnabled) {
      return const FocusReward(points: 0, experience: 0);
    }

    final partial =
        session.status == FocusSessionStatus.cancelled &&
        config.partialRewardEnabled &&
        session.actualFocusDuration.inSeconds > 0;
    if (!completed && !partial) {
      return const FocusReward(points: 0, experience: 0);
    }

    final multiplier = partial ? config.partialRewardMultiplier : 1.0;
    final points = (focusedMinutes * config.pointsPerFocusedMinute * multiplier)
        .round();
    final experience =
        (focusedMinutes * config.pointsPerFocusedMinute * multiplier).round();
    final bonus = completed ? config.completionBonus : 0;

    return FocusReward(
      points: points + bonus,
      experience: experience + bonus,
      metadata: {'completed': completed, 'partial': partial},
    );
  }
}
