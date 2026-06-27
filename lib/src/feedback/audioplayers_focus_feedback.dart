import 'package:audioplayers/audioplayers.dart';
import 'package:focus_quest/src/feedback/focus_feedback.dart';

/// Audio feedback implementation backed by the `audioplayers` package.
class AudioplayersFocusFeedback implements FocusFeedback {
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
  final String? startedAsset;
  final String? pausedAsset;
  final String? resumedAsset;
  final String? completedAsset;
  final String? cancelledAsset;
  final String? levelUpAsset;
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
