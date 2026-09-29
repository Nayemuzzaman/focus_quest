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
- Pluggable level curve with level-up feedback and progress values for XP bars
- Typed event stream for session transitions, level-ups, streaks, and daily goals
- Daily goal progress, current streak, longest streak, completion rate, and history
- In-memory, SharedPreferences-backed, and Hive-backed local persistence
- Storage abstraction for custom Isar, SQLite, secure storage, or backend adapters
- Riverpod notifier and immutable state for Flutter apps
- Drop-in `WidgetsBindingObserver` that forwards app lifecycle changes
- Optional haptic feedback and audioplayers-based sound feedback
- Test-friendly clock, storage, and strategy abstractions

## Supported platforms

The core Dart logic works anywhere Flutter runs. The included
`SharedPreferencesFocusQuestStorage` and `HiveFocusQuestStorage` support the
platforms covered by their underlying packages. App lifecycle behavior depends
on Flutter lifecycle events from the host app.

Supported platforms:

- Android
- iOS
- macOS
- Windows
- Linux

Web is not supported yet: the bundled `audioplayers` adapter depends on
`path_provider`, which has no web implementation. Splitting the optional
adapters into separate packages is planned so the core can run on the web.

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

`initialize()` never throws: if storage fails it records the message in
`state.error`, and `isInitialized` stays false until a later call succeeds.
Session actions such as `start` and `pause` throw `FocusQuestException` when
the controller is not initialized or the transition is invalid.

## Riverpod usage

`focus_quest` includes a Riverpod notifier that coordinates the reusable
controller. Domain logic stays in the controller instead of being embedded in
UI widgets.

Override `focusQuestControllerProvider` to choose storage, configuration,
feedback, and strategies (the default controller keeps everything in memory),
then watch `focusQuestInitializationProvider` so the controller is initialized
before any action runs:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        focusQuestControllerProvider.overrideWith(
          (ref) => FocusQuestController(
            storage: SharedPreferencesFocusQuestStorage(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class FocusButton extends ConsumerWidget {
  const FocusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(focusQuestInitializationProvider);
    final state = ref.watch(focusQuestStateProvider);
    final notifier = ref.read(focusQuestStateProvider.notifier);

    return initialization.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('$error'),
      data: (_) => ElevatedButton(
        onPressed: state.status == FocusSessionStatus.running
            ? null
            : () => notifier.start(duration: const Duration(minutes: 25)),
        child: Text(state.status.name),
      ),
    );
  }
}
```

The controller provided by `focusQuestControllerProvider` is disposed together
with its `ProviderScope`.

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

## Levels

Total experience maps to a level through a `LevelStrategy`. The default curve
requires `levelBaseXp * (level - 1) ^ levelExponent` experience to reach a
level (100, 230, 373, 528, ... with the default configuration). Statistics
expose `currentLevel`, `progressToNextLevel`, `experienceToNextLevel`, and
`levelProgress` (0.0 to 1.0) for XP bars, and `FocusFeedback.onLevelUp` runs
whenever a finalized session raises the level.

```dart
class LinearLevelStrategy implements LevelStrategy {
  const LinearLevelStrategy();

  @override
  int experienceForLevel(int level, FocusQuestConfig config) =>
      (level - 1) * config.levelBaseXp;

  @override
  int levelForExperience(int experience, FocusQuestConfig config) =>
      experience ~/ config.levelBaseXp + 1;
}

final controller = FocusQuestController(
  levelStrategy: const LinearLevelStrategy(),
);
```

Stored levels are recomputed from total experience during `initialize()`, so
changing the strategy or upgrading the package keeps profiles consistent.

## Events

`controller.events` is a broadcast stream of sealed `FocusQuestEvent`s, so a
`switch` over it is exhaustive. Use it to drive your game layer instead of
comparing state snapshots:

```dart
controller.events.listen((event) {
  switch (event) {
    case FocusSessionCompletedEvent(:final session, :final completedWhileAway):
      garden.growTree(minutes: session.actualFocusDuration.inMinutes);
      if (completedWhileAway) showToast('Your tree grew while you were away');
    case FocusLevelUpEvent(:final newLevel):
      showToast('Level $newLevel!');
    case FocusStreakIncreasedEvent(:final currentStreak):
      showToast('$currentStreak-day streak');
    case FocusDailyGoalReachedEvent():
      showToast('Daily goal reached');
    case FocusSessionStartedEvent() ||
        FocusSessionPausedEvent() ||
        FocusSessionResumedEvent() ||
        FocusSessionCancelledEvent() ||
        FocusSessionFailedEvent():
      break;
  }
});

await controller.initialize();
```

- Subscribe **before** `initialize()` to receive the completion of a session
  that reached its target while the app was not running.
- Events are emitted after `controller.state` has been updated and before
  `FocusFeedback` hooks run.
- For a single session the order is: the session event, then
  `FocusLevelUpEvent`, `FocusStreakIncreasedEvent`, and
  `FocusDailyGoalReachedEvent` when they apply.
- The stream is closed when the controller is disposed.

With Riverpod, listen to `focusQuestEventsProvider`:

```dart
ref.listen(focusQuestEventsProvider, (_, next) {
  if (next.value case FocusLevelUpEvent(:final newLevel)) {
    showToast('Level $newLevel!');
  }
});
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

Attach a `FocusQuestLifecycleObserver`, or call `handleLifecycleEvent` from
your own `WidgetsBindingObserver`. The configured background behavior decides
whether the active session pauses, cancels, or keeps running when the app
moves away from the foreground.

```dart
final controller = FocusQuestController(
  config: const FocusQuestConfig(
    backgroundBehavior: BackgroundBehavior.pause,
    maxInterruptions: 3,
  ),
);

// In a State: attach in initState, detach in dispose.
final observer = FocusQuestLifecycleObserver(controller)..attach();

// Or forward events yourself:
await controller.handleLifecycleEvent(FocusLifecycleEvent.paused);
```

Semantics:

- `paused` and `detached` count one interruption and apply the background
  behavior, but only while the session is running. Events for a session that
  is already paused are ignored, so platforms that emit `inactive`, `hidden`,
  and `paused` back to back never double count.
- `inactive` and `resumed` never change the session; they are only forwarded
  to the optional `lifecycleHandler`.
- When the interruption count exceeds `maxInterruptions` the session fails.
- Events are processed in order even when they arrive concurrently.

Elapsed and remaining time are calculated from timestamps, not only from
one-second ticks. This keeps sessions accurate if the app is delayed, suspended,
or restored later. A running session restored after a restart completes at the
moment its target was reached and never earns more than its target duration.

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

Feedback hooks run after the new state has been published and are isolated
from session logic: an exception thrown by a hook is reported through
`FlutterError.reportError` and never changes the session.

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
- If the OS kills the app while a session is running, no lifecycle event is
  delivered. The session is restored on the next launch and completes at the
  moment its target was reached; the `pause` and `cancel` background behaviors
  cannot be applied retroactively yet.
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

- Optional adapter packages so the core no longer depends on `audioplayers`,
  Hive, or Riverpod (and can run on the web)
- Pomodoro breaks and cycles, auto-resume on foreground, history retention
- Richer streak policies and calendar rules
- Share-card helpers for streaks, pets, gardens, and charity progress

## Contributing

Issues and pull requests are welcome. See `CONTRIBUTING.md` and
`CODE_OF_CONDUCT.md` for project expectations.
