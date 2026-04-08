import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

/// Bridges audio_service (lock screen / notification) with SoLoud playback.
/// SoLoud does the actual audio — this class just handles the media controls
/// that come from the notification bar and lock screen buttons.
class SoundVaultAudioHandler extends BaseAudioHandler
    with SeekHandler {

  Future<void> Function()? _onSkipNext;
Future<void> Function()? _onSkipPrev;
  VoidCallback? _onPlay;
  VoidCallback? _onPause;
  void Function(double)? _onSeek;

  void setSkipCallbacks({
  required Future<void> Function() onNext,
  required Future<void> Function() onPrev,
}) {
  _onSkipNext = onNext;
  _onSkipPrev = onPrev;
}

  void setPlaybackCallbacks({
  required VoidCallback onPlay,
  required VoidCallback onPause,
  required void Function(double progress) onSeek,
}) {
  _onPlay = onPlay;
  _onPause = onPause;
  _onSeek = onSeek;
}

  // Called when user taps Play on lock screen / notification
  @override
Future<void> play() async => _onPlay?.call();

@override
Future<void> pause() async => _onPause?.call();

  // Called when user taps Next
  @override
Future<void> skipToNext() async {
  await _onSkipNext?.call();
}

@override
Future<void> skipToPrevious() async {
  await _onSkipPrev?.call();
}

  // Called when user seeks from lock screen
  @override
  Future<void> seek(Duration position) async {
    // We receive absolute position, convert to progress 0.0–1.0
    final total = mediaItem.value?.duration ?? Duration.zero;
    if (total.inMilliseconds > 0) {
      final progress = position.inMilliseconds / total.inMilliseconds;
      _onSeek?.call(progress.clamp(0.0, 1.0));
    }
  }

  @override
  Future<void> stop() async {
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
    ));
  }
}