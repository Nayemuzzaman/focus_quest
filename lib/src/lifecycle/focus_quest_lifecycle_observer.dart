import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:focus_quest/src/controller/focus_quest_controller.dart';
import 'package:focus_quest/src/lifecycle/focus_lifecycle.dart';

/// Maps a Flutter [AppLifecycleState] to the matching [FocusLifecycleEvent].
///
/// [AppLifecycleState.hidden] maps to [FocusLifecycleEvent.paused] because
/// desktop platforms never report `paused`; the controller ignores repeated
/// backgrounding events, so mobile platforms that report both are safe.
FocusLifecycleEvent focusLifecycleEventFor(AppLifecycleState state) {
  return switch (state) {
    AppLifecycleState.resumed => FocusLifecycleEvent.resumed,
    AppLifecycleState.inactive => FocusLifecycleEvent.inactive,
    AppLifecycleState.hidden => FocusLifecycleEvent.paused,
    AppLifecycleState.paused => FocusLifecycleEvent.paused,
    AppLifecycleState.detached => FocusLifecycleEvent.detached,
  };
}

/// Forwards Flutter app lifecycle changes to a [FocusQuestController].
///
/// Register it with `WidgetsBinding.instance.addObserver` (or call [attach])
/// and remove it again with [detach] when the host widget is disposed.
class FocusQuestLifecycleObserver extends WidgetsBindingObserver {
  /// Creates an observer that drives [controller].
  FocusQuestLifecycleObserver(this.controller);

  /// Controller that receives the mapped lifecycle events.
  final FocusQuestController controller;

  /// Registers this observer with the current [WidgetsBinding].
  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Unregisters this observer from the current [WidgetsBinding].
  void detach() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(controller.handleLifecycleEvent(focusLifecycleEventFor(state)));
  }
}
