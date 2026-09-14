## 0.0.3

### Fixed

* Lifecycle events for an already paused session no longer throw or double count interruptions; `detached` now applies the background behavior, `inactive` and `resumed` never touch the session, and concurrent events are processed in order.
* Current streak is recomputed from history whenever statistics are built, so it drops to zero after missed days instead of showing the value stored at the last session.
* Streak and daily/weekly/monthly totals use calendar-day arithmetic that is stable across daylight-saving transitions.
* Level calculation now follows the documented curve (`levelBaseXp * (level - 1) ^ levelExponent`), `progressToNextLevel` matches it, and stored levels are reconciled on `initialize()`.
* `FocusFeedback.onLevelUp` is invoked when a finalized session raises the level.
* `FocusStatistics.cancelledSessions` includes failed sessions like the profile does; `completionRate` counts them too.
* A running session restored after the app was killed completes at the moment its target was reached, is credited at most the target duration, and is attributed to that day.
* `start()` rejects non-positive durations and no longer leaves an active session behind when persistence fails.
* `complete()` throws `FocusQuestException` instead of `StateError` for already finalized sessions.
* Feedback hooks run after state is published and their failures are reported through `FlutterError.reportError` instead of breaking the session.
* `focusQuestControllerProvider` disposes its controller with the container.

### Added

* `LevelStrategy` and `DefaultLevelStrategy`, injectable through `FocusQuestController(levelStrategy: ...)`.
* `FocusStatistics.experienceToNextLevel`, `FocusStatistics.levelProgress`, and `FocusStatistics.failedSessions`.
* `FocusQuestLifecycleObserver` and `focusLifecycleEventFor` for forwarding `AppLifecycleState` changes.
* `focusQuestInitializationProvider` for awaiting controller initialization with Riverpod.
* `FocusQuestConfig` assertions for invalid reward, level, and interruption values.
* Continuous integration running analysis, formatting, tests in several time zones, and a publish dry run.

### Changed

* README documents the corrected Riverpod setup, lifecycle semantics, level curve, and the current web limitation.
* Example app uses `FocusQuestLifecycleObserver`, surfaces errors, and shows level progress.

## 0.0.2

* Added timestamp-driven controller ticker behavior for state refresh and automatic session completion.
* Hardened lifecycle interruption handling, streak calculation, restart completion restoration, reset persistence behavior, and Riverpod listener cleanup.
* Expanded package tests for rewards, invalid transitions, persistence, lifecycle behavior, streaks, error handling, and Riverpod actions.
* Excluded generated build and coverage artifacts from publish archives.
* Improved pub.dev metadata and documentation for anti-doomscroll, virtual pet, virtual garden, and charity-progress use cases.
* Added first-party `HiveFocusQuestStorage` and `AudioplayersFocusFeedback` adapters.
* Updated Riverpod integration for `flutter_riverpod` 3.x and expanded dartdoc comments across the public API.

## 0.0.1

* Initial release of focus_quest with a reusable focus-session controller, configuration, storage abstractions, default reward strategy, Riverpod integration, lifecycle hooks, and a basic example app.
