import 'package:audioplayers/audioplayers.dart';
import 'package:focus_quest/src/feedback/focus_feedback.dart';

/// Audio feedback implementation backed by the `audioplayers` package.
class AudioplayersFocusFeedback implements FocusFeedback {
  /// Creates asset-based audio feedback hooks.
  AudioplayersFocusFeedback({
    AudioPlayer? player,
    this.startedAsset,
    this.pausedAsset,
    this.resumedAsset,
    this.completedAsset,
    this.cancelledAsset,
    this.levelUpAsset,
    this.volume = 1.0,
  }) {
    _player = player;
  }

  AudioPlayer? _player;

  /// Asset path played when a session starts.
  final String? startedAsset;

  /// Asset path played when a session pauses.
  final String? pausedAsset;

  /// Asset path played when a session resumes.
  final String? resumedAsset;

  /// Asset path played when a session completes.
  final String? completedAsset;

  /// Asset path played when a session is cancelled.
  final String? cancelledAsset;

  /// Asset path played when the profile levels up.
  final String? levelUpAsset;

  /// Playback volume passed to the audio player.
  final double volume;

  @override
  Future<void> onSessionStarted() => _play(startedAsset);

  @override
  Future<void> onSessionPaused() => _play(pausedAsset);

  @override
  Future<void> onSessionResumed() => _play(resumedAsset);

  @override
  Future<void> onSessionCompleted() => _play(completedAsset);

  @override
  Future<void> onSessionCancelled() => _play(cancelledAsset);

  @override
  Future<void> onLevelUp() => _play(levelUpAsset);

  /// Releases the underlying audio player when the host app owns this object.
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }

  Future<void> _play(String? assetPath) async {
    if (assetPath == null || assetPath.isEmpty) {
      return;
    }

    final player = _player ??= AudioPlayer();
    await player.play(AssetSource(assetPath), volume: volume);
  }
}
