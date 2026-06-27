# focus_quest

A reusable gamified focus and anti-doomscroll productivity engine for Flutter.

`focus_quest` provides the core logic needed to build Pomodoro apps, study
timers, habit trackers, digital wellbeing tools, virtual pet focus apps,
virtual garden apps, and other gamified productivity experiences. The package
handles focus sessions, countdown state, rewards, streaks, persistence,
lifecycle behavior, optional feedback, and Riverpod integration while leaving
the app developer free to design any UI, theme, game world, or reward system.

## Why use focus_quest?

Building a focus app usually requires more than a timer. Apps need accurate
pause and resume behavior, restore support after app restarts, background
interruption handling, local history, streaks, points, XP, and clean state
management. `focus_quest` packages those pieces as reusable business logic so
you can spend more time building the experience your users see.

It is especially useful for anti-doomscroll apps where staying away from the
phone can grow a virtual forest, feed a pet, unlock collectibles, or record
charity-progress metadata.

The package tracks app-level focus sessions. It does not block, inspect, or
monitor other installed apps.

## Features

- Start, pause, resume, complete, cancel, reset, and restore focus sessions
- Timestamp-based countdowns that stay accurate after delayed timer ticks
- Configurable background behavior: pause, cancel, or keep running
- Points, XP, completion bonuses, partial rewards, and custom reward metadata
- Daily goal progress, current streak, longest streak, completion rate, and history
- In-memory, SharedPreferences-backed, and Hive-backed local persistence
- Storage abstraction for custom Isar, SQLite, secure storage, or backend adapters
- Riverpod notifier and immutable state for Flutter apps
- Optional haptic feedback and audioplayers-based sound feedback
- Test-friendly clock, storage, and strategy abstractions

## Supported platforms

The core Dart logic works anywhere Flutter runs. The included
`SharedPreferencesFocusQuestStorage` and `HiveFocusQuestStorage` support the
platforms covered by their underlying packages. App lifecycle behavior depends
on Flutter lifecycle events from the host app.

Target platforms:

- Android
- iOS
- Web
- macOS
- Windows
- Linux

## Installation

```bash
flutter pub add focus_quest
```

Then import the package:

```dart
import 'package:focus_quest/focus_quest.dart';
```

## Quick start

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
  print('Current streak: ${state.currentStreak}');
}
```

## Riverpod usage

`focus_quest` includes a Riverpod notifier that coordinates the reusable
controller. Domain logic stays in the controller instead of being embedded in
UI widgets.

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

## Custom rewards

Reward metadata can drive your own game layer. For example, one app might use
it to grow trees, another might feed a virtual pet, and another might record
charity-progress data that is later processed by its own backend.

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

## Storage

Use the storage implementation that fits your app:

- `InMemoryFocusQuestStorage` for tests and prototypes
- `SharedPreferencesFocusQuestStorage` for lightweight local persistence
- `HiveFocusQuestStorage` for Hive-backed local persistence
- A custom `FocusQuestStorage` implementation for other databases or backends

```dart
final controller = FocusQuestController(
  storage: HiveFocusQuestStorage(boxName: 'my_focus_app'),
);
```

For a custom store, persist `FocusSession.toJson()` and `FocusProfile.toJson()`,
then restore them with `FocusSession.fromJson()` and `FocusProfile.fromJson()`.

## Lifecycle behavior

Call `handleLifecycleEvent` from your app lifecycle observer. The configured
background behavior decides whether the active session pauses, cancels, or keeps
running when the app moves away from the foreground.

```dart
final controller = FocusQuestController(
  config: const FocusQuestConfig(
    backgroundBehavior: BackgroundBehavior.pause,
    maxInterruptions: 3,
  ),
);

await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);
```

Elapsed and remaining time are calculated from timestamps, not only from
one-second ticks. This keeps sessions accurate if the app is delayed, suspended,
or restored later.

## Feedback and sound

The package includes:

- `NoopFocusFeedback` for silent behavior
- `FlutterFocusFeedback` for haptics
- `AudioplayersFocusFeedback` for optional asset-based sound effects

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

## Example application

See the `example/` directory for a small Flutter app that demonstrates:

- Controller initialization
- Starting, pausing, resuming, completing, and cancelling sessions
- Remaining time and daily progress
- Streak and history display
- Lifecycle handling
- Local persistence

## Platform limitations

- App-level lifecycle tracking is supported.
- Device-wide app usage tracking is not included.
- App blocking is not included.
- Charity donations must be implemented by the host app through its own backend
  or payment/donation provider. `focus_quest` can store reward metadata for that
  flow, but it does not transfer money.


## Website

For updates, support, and related package information, visit
[csjotlab.com](https://csjotlab.com/).

## Features and bugs

Please file feature requests and bugs at the
[issue tracker](https://github.com/Nayemuzzaman/focus_quest/issues).

## Roadmap

- Richer streak policies and calendar rules
- Share-card helpers for streaks, pets, gardens, and charity progress
- More polished example screens for anti-doomscroll app concepts

## Contributing

Issues and pull requests are welcome. See `CONTRIBUTING.md` and
`CODE_OF_CONDUCT.md` for project expectations.
