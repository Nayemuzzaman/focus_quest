import 'package:focus_quest/src/controller/focus_quest_controller.dart';
import 'package:focus_quest/src/models/focus_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the default [FocusQuestController] used by Riverpod integrations.
final focusQuestControllerProvider = Provider<FocusQuestController>((ref) {
  return FocusQuestController();
});

/// Provides immutable focus state and exposes focus-session actions.
final focusQuestStateProvider =
    NotifierProvider<FocusQuestNotifier, FocusQuestState>(
      FocusQuestNotifier.new,
    );

/// Riverpod notifier that coordinates a [FocusQuestController].
class FocusQuestNotifier extends Notifier<FocusQuestState> {
  late final FocusQuestController controller;

  @override
  FocusQuestState build() {
    controller = ref.watch(focusQuestControllerProvider);
    controller.addListener(_sync);
    ref.onDispose(() {
      controller.removeListener(_sync);
    });
    return controller.state;
  }

  /// Initializes storage, restores sessions, and refreshes state.
  Future<void> initialize() async {
    await controller.initialize();
    state = controller.state;
  }

  /// Starts a new focus session.
  Future<void> start({
    Duration? duration,
    Map<String, Object?>? metadata,
  }) async {
    await controller.start(duration: duration, metadata: metadata);
    state = controller.state;
  }

  /// Pauses the active running session.
  Future<void> pause() async {
    await controller.pause();
    state = controller.state;
  }

  /// Resumes the active paused session.
  Future<void> resume() async {
    await controller.resume();
    state = controller.state;
  }

  /// Completes the active session and applies rewards.
  Future<void> complete() async {
    await controller.complete();
    state = controller.state;
  }

  /// Cancels the active session with an optional reason.
  Future<void> cancel({String? reason}) async {
    await controller.cancel(reason: reason);
    state = controller.state;
  }

  /// Resets the active session state.
  Future<void> reset() async {
    await controller.reset();
    state = controller.state;
  }

  /// Recomputes statistics from the current controller state.
  Future<void> refreshStatistics() async {
    await controller.refreshStatistics();
    state = controller.state;
  }

  /// Clears the current error value.
  Future<void> clearError() async {
    await controller.clearError();
    state = controller.state;
  }

  void _sync() {
    state = controller.state;
  }
}
