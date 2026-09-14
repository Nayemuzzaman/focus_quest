/// App lifecycle events understood by the focus controller.
enum FocusLifecycleEvent {
  /// The app moved to the background; applies the background behavior.
  paused,

  /// The app returned to the foreground; forwarded only.
  resumed,

  /// The app lost focus without leaving the foreground; forwarded only.
  inactive,

  /// The app is shutting down; applies the background behavior.
  detached,
}

/// Receives lifecycle events from a host Flutter app.
abstract class FocusLifecycleHandler {
  /// Allows subclasses to declare const constructors.
  const FocusLifecycleHandler();

  /// Handles a lifecycle [event].
  Future<void> handleLifecycleEvent(FocusLifecycleEvent event);
}

/// Simple lifecycle handler that delegates events to a callback.
class FocusLifecycleBridge implements FocusLifecycleHandler {
  /// Creates a bridge from a lifecycle event callback.
  FocusLifecycleBridge(this.onEvent);

  /// Callback invoked for each lifecycle event.
  final Future<void> Function(FocusLifecycleEvent event) onEvent;

  @override
  Future<void> handleLifecycleEvent(FocusLifecycleEvent event) =>
      onEvent(event);
}
