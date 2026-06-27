## 0.0.1

* Initial release of focus_quest with a reusable focus-session controller, configuration, storage abstractions, default reward strategy, Riverpod integration, lifecycle hooks, and a basic example app.
* Added timestamp-driven controller ticker behavior for state refresh and automatic session completion.
* Hardened lifecycle interruption handling, streak calculation, restart completion restoration, reset persistence behavior, and Riverpod listener cleanup.
* Expanded package tests for rewards, invalid transitions, persistence, lifecycle behavior, streaks, error handling, and Riverpod actions.
* Excluded generated build and coverage artifacts from publish archives.
* Improved pub.dev metadata and documentation for anti-doomscroll, virtual pet, virtual garden, and charity-progress use cases.
* Added first-party `HiveFocusQuestStorage` and `AudioplayersFocusFeedback` adapters.
* Updated Riverpod integration for `flutter_riverpod` 3.x and expanded dartdoc comments across the public API.
