import 'package:flutter/services.dart';

/// Optional feedback hooks for session lifecycle events.
abstract class FocusFeedback {
  /// Called after a session starts.
  Future<void> onSessionStarted();

  /// Called after a session pauses.
  Future<void> onSessionPaused();

  /// Called after a session resumes.
  Future<void> onSessionResumed();

  /// Called after a session completes.
  Future<void> onSessionCompleted();

  /// Called after a session is cancelled.
  Future<void> onSessionCancelled();

  /// Called after the user profile levels up.
  Future<void> onLevelUp();
}

/// Feedback implementation that intentionally does nothing.
class NoopFocusFeedback implements FocusFeedback {
  /// Creates no-op feedback hooks.
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

/// Haptic feedback implementation backed by Flutter services.
class FlutterFocusFeedback implements FocusFeedback {
  /// Creates haptic feedback hooks.
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
