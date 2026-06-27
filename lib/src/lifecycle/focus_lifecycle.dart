enum FocusLifecycleEvent { paused, resumed, inactive, detached }

abstract class FocusLifecycleHandler {
  Future<void> handleLifecycleEvent(FocusLifecycleEvent event);
}

class FocusLifecycleBridge implements FocusLifecycleHandler {
  FocusLifecycleBridge(this.onEvent);

  final Future<void> Function(FocusLifecycleEvent event) onEvent;

  @override
  Future<void> handleLifecycleEvent(FocusLifecycleEvent event) =>
      onEvent(event);
}
