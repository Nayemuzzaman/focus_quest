import 'package:flutter/services.dart';

/// Optional feedback hooks for session lifecycle events.
abstract class FocusFeedback {
  Future<void> onSessionStarted();
  Future<void> onSessionPaused();
  Future<void> onSessionResumed();
  Future<void> onSessionCompleted();
  Future<void> onSessionCancelled();
  Future<void> onLevelUp();
}

class NoopFocusFeedback implements FocusFeedback {
  const NoopFocusFeedback();

  @override
  Future<void> onSessionStarted() async {}

  @override
  Future<void> onSessionPaused() async {}

  @override
  Future<void> onSessionResumed() async {}

  @override
  Future<void> onSessionCompleted() async {}

  @override
  Future<void> onSessionCancelled() async {}

  @override
  Future<void> onLevelUp() async {}
}

class FlutterFocusFeedback implements FocusFeedback {
  const FlutterFocusFeedback();

  @override
  Future<void> onSessionStarted() async {
    await HapticFeedback.mediumImpact();
  }

  @override
  Future<void> onSessionPaused() async {
    await HapticFeedback.lightImpact();
  }

  @override
  Future<void> onSessionResumed() async {
    await HapticFeedback.selectionClick();
  }

  @override
  Future<void> onSessionCompleted() async {
    await HapticFeedback.heavyImpact();
  }

  @override
  Future<void> onSessionCancelled() async {
    await HapticFeedback.lightImpact();
  }

  @override
  Future<void> onLevelUp() async {
    await HapticFeedback.heavyImpact();
  }
}
