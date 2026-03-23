import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Bridges just_audio with audio_service for media notifications
/// and lock screen controls on Android.
class SoundVaultAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  SoundVaultAudioHandler() {
    _initStreams();
  }

  AudioPlayer get player => _player;

  void _initStreams() {
    // Forward playback state to audio_service
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Forward current song as mediaItem
    _player.sequenceStateStream.listen((state) {
      if (state?.currentSource?.tag is MediaItem) {
        mediaItem.add(state!.currentSource!.tag as MediaItem);
      }
    });

    // Auto advance
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    // Handled by PlayerService
    await super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await super.skipToPrevious();
  }

  @override
  Future<void> playSong(MediaItem item, String filePath) async {
  mediaItem.add(item);
  await _player.setAudioSource(
    AudioSource.uri(Uri.file(filePath), tag: item),
  );
  await _player.play();
}

  @override
  Future<void> dispose() async {
    await _player.dispose();
    return super.stop();
  }
}
