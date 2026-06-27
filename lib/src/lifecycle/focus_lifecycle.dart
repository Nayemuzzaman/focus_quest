/// App lifecycle events understood by the focus controller.
enum FocusLifecycleEvent { paused, resumed, inactive, detached }

/// Receives lifecycle events from a host Flutter app.
abstract class FocusLifecycleHandler {
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
