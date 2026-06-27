# focus_quest

A reusable gamified focus and anti-doomscroll productivity engine for Flutter.

`focus_quest` gives app developers the business logic for focus sessions,
rewards, streaks, levels, statistics, persistence, lifecycle handling, optional
feedback, and Riverpod state. You bring the UI: a virtual pet, garden, study
timer, charity tracker, team focus tool, or any other game layer.

## Features

- Start, pause, resume, complete, cancel, reset, and restore focus sessions
- Timestamp-based countdowns that stay accurate after delayed timer ticks
- Configurable background behavior: pause, cancel, or keep running
- Points, XP, completion bonuses, partial rewards, and custom reward metadata
- Daily goal progress, current streak, longest streak, completion rate, and history
- In-memory, SharedPreferences-backed, and Hive-backed local persistence
- Storage abstraction for custom Isar, SQLite, secure storage, or backend adapters
- Riverpod notifier and immutable state for Flutter apps
- Optional haptic and audioplayers feedback hooks with a no-op default

## Use Cases

`focus_quest` is suitable for anti-doomscroll apps where staying away from the
phone can grow a virtual forest, feed a pet, unlock collectibles, or record
charity-impact metadata. It is also useful for Pomodoro apps, study timers,
habit trackers, digital wellbeing products, and employee focus tools.

The package tracks app-level focus sessions. It does not block, inspect, or
monitor other installed apps.

## Supported Platforms

The core Dart logic works anywhere Flutter runs. The bundled
`SharedPreferencesFocusQuestStorage` depends on `shared_preferences`, which
supports Android, iOS, web, macOS, Windows, and Linux. Lifecycle behavior is
app-level and depends on Flutter lifecycle events from the host app.

## Installation

```bash
flutter pub add focus_quest
```

## Quick Start

```dart
import 'package:focus_quest/focus_quest.dart';

Future<void> main() async {
  final controller = FocusQuestController(
    storage: SharedPreferencesFocusQuestStorage(),
  );

  await controller.initialize();
  await controller.start(
    duration: const Duration(minutes: 25),
    metadata: {
      'category': 'study',
      'task': 'Japanese vocabulary',
    },
  );

  await controller.pause();
  await controller.resume();
  await controller.complete();

  final state = controller.state;
  print('Points: ${state.totalPoints}');
  print('Streak: ${state.currentStreak}');
}
```

## Riverpod Usage

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/focus_quest.dart';

class FocusButton extends ConsumerWidget {
  const FocusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusQuestStateProvider);
    final notifier = ref.read(focusQuestStateProvider.notifier);

    return ElevatedButton(
      onPressed: state.status == FocusSessionStatus.running
          ? null
          : () => notifier.start(duration: const Duration(minutes: 25)),
      child: Text(state.status.name),
    );
  }
}
```

## Custom Reward Strategy

Use reward metadata to drive your own game world, pet, garden, or charity UI.

```dart
class GardenRewardStrategy implements RewardStrategy {
  @override
  FocusReward calculate(FocusSession session, FocusQuestConfig config) {
    final focusedMinutes = session.actualFocusDuration.inMinutes;
    final completed = session.status == FocusSessionStatus.completed;

    return FocusReward(
      points: completed ? focusedMinutes + config.completionBonus : 0,
      experience: focusedMinutes * 2,
      metadata: {
        'treeGrowth': focusedMinutes,
        'petFood': focusedMinutes ~/ 5,
        'charityCents': completed ? focusedMinutes : 0,
      },
    );
  }
}
```

## Storage Customization

Use `InMemoryFocusQuestStorage` in tests,
`SharedPreferencesFocusQuestStorage` for lightweight local persistence, or
`HiveFocusQuestStorage` for a Hive-backed store.

```dart
final controller = FocusQuestController(
  storage: HiveFocusQuestStorage(boxName: 'my_focus_app'),
);
```

For a different database or backend, implement `FocusQuestStorage` and persist
`FocusSession.toJson()` plus `FocusProfile.toJson()`.

## Lifecycle Behavior

Call `handleLifecycleEvent` from your app lifecycle observer. The configured
background behavior decides whether the active session pauses, cancels, or keeps
running.

```dart
controller = FocusQuestController(
  config: const FocusQuestConfig(
    backgroundBehavior: BackgroundBehavior.pause,
    maxInterruptions: 3,
  ),
);

await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);
```

Elapsed and remaining time are calculated from timestamps, not only from
one-second ticks. The controller prevents duplicate active timers and finalizes
completed sessions once.

## Optional Feedback and Audio

The package includes `FocusFeedback`, `NoopFocusFeedback`,
`FlutterFocusFeedback` for haptics, and `AudioplayersFocusFeedback` for
optional asset-based sound effects.

```dart
final controller = FocusQuestController(
  feedback: AudioplayersFocusFeedback(
    startedAsset: 'sounds/start.mp3',
    completedAsset: 'sounds/complete.mp3',
    levelUpAsset: 'sounds/level-up.mp3',
  ),
);
```

Sound assets are optional. Declare any assets you use in the host app's
`pubspec.yaml`.

## Example Application

See `example/` for a small app that initializes the controller, starts focus
sessions, handles lifecycle changes, displays progress, and persists state.

## Platform Limitations

- App-level lifecycle tracking is supported.
- Device-wide app usage tracking is not included.
- App blocking is not included.
- Charity donations must be implemented by the app through its own backend or
  payment/donation provider. `focus_quest` can store reward metadata for that
  flow, but it does not transfer money.

## Testing

```bash
flutter test
flutter test --coverage
cd example && flutter test
dart pub publish --dry-run
```

## Roadmap

- Richer streak policies and calendar rules
- Share-card helpers for streaks, pets, gardens, and charity progress

## Contributing

Issues and pull requests are welcome. See `CONTRIBUTING.md` and
`CODE_OF_CONDUCT.md` for project expectations.
