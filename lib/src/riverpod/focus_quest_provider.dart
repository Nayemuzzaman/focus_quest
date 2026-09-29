import 'package:focus_quest/src/controller/focus_quest_controller.dart';
import 'package:focus_quest/src/events/focus_quest_event.dart';
import 'package:focus_quest/src/exceptions/focus_quest_exception.dart';
import 'package:focus_quest/src/models/focus_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [FocusQuestController] used by Riverpod integrations.
///
/// The default controller uses in-memory storage. Override this provider to
/// supply persistent storage, configuration, feedback, or strategies:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     focusQuestControllerProvider.overrideWith(
///       (ref) => FocusQuestController(
///         storage: SharedPreferencesFocusQuestStorage(),
///       ),
///     ),
///   ],
///   child: const MyApp(),
/// )
/// ```
final focusQuestControllerProvider = Provider<FocusQuestController>((ref) {
  final controller = FocusQuestController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Initializes the shared controller so widgets can await it before use.
///
/// Watch it (for example with `ref.watch(focusQuestInitializationProvider)`)
/// to render a loading or error state while storage is restored. The future
/// fails with a [FocusQuestException] when initialization does not succeed;
/// automatic retries are disabled so the failure is reported immediately, and
/// the host app can retry with `ref.invalidate(focusQuestInitializationProvider)`.
final focusQuestInitializationProvider = FutureProvider<void>((ref) async {
  final notifier = ref.read(focusQuestStateProvider.notifier);
  // The controller notifies synchronously when initialization starts, which
  // would update the state notifier while this provider is still building.
  await null;
  await notifier.initialize();
  if (!notifier.controller.isInitialized) {
    throw FocusQuestException(
      notifier.controller.error ?? 'Focus quest initialization failed.',
    );
  }
}, retry: (retryCount, error) => null);

/// Streams [FocusQuestEvent]s from the controller in
/// [focusQuestControllerProvider].
///
/// A [StreamProvider] only keeps the latest value, so react to each event with
/// `ref.listen` rather than `ref.watch`:
///
/// ```dart
/// ref.listen(focusQuestEventsProvider, (_, next) {
///   switch (next.value) {
///     case FocusLevelUpEvent(:final newLevel):
///       showLevelUpToast(newLevel);
///     case _:
///       break;
///   }
/// });
/// ```
final focusQuestEventsProvider = StreamProvider<FocusQuestEvent>(
  (ref) => ref.watch(focusQuestControllerProvider).events,
  retry: (retryCount, error) => null,
);

/// Provides immutable focus state and exposes focus-session actions.
final focusQuestStateProvider =
    NotifierProvider<FocusQuestNotifier, FocusQuestState>(
      FocusQuestNotifier.new,
    );

/// Riverpod notifier that coordinates a [FocusQuestController].
class FocusQuestNotifier extends Notifier<FocusQuestState> {
  /// Creates a notifier; Riverpod instantiates it through
  /// [focusQuestStateProvider].
  FocusQuestNotifier();

  /// Controller resolved from [focusQuestControllerProvider] in [build].
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
