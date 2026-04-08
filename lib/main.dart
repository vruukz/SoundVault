import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/player_service.dart';
import 'services/audio_handler.dart';

late SoundVaultAudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize audio_service so lock screen / notification controls work
  _audioHandler = await AudioService.init(
    builder: () => SoundVaultAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.soundvault.audio',
      androidNotificationChannelName: 'SoundVault',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(SoundVaultApp(audioHandler: _audioHandler));
}

class SoundVaultApp extends StatelessWidget {
  final SoundVaultAudioHandler audioHandler;
  const SoundVaultApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final service = PlayerService();

        // Wire skip callbacks so lock screen buttons control SoLoud playback
        audioHandler.setPlaybackCallbacks(
  onPlay: () {
    if (!service.isPlaying) service.togglePlay();
  },
  onPause: () {
    if (service.isPlaying) service.togglePlay();
  },
  onSeek: service.seekTo,
);
audioHandler.setSkipCallbacks(
  onNext: service.skipNext,
  onPrev: service.skipPrev,
);
        // Whenever PlayerService changes, push updated MediaItem + state
        // to audio_service so the notification bar stays in sync
        service.addListener(() {
          final song = service.currentSong;
          if (song != null) {
            final item = MediaItem(
              id: song.filePath,
              title: song.title,
              artist: song.artist,
              album: song.album,
              artUri: song.albumArtPath != null
                  ? Uri.file(song.albumArtPath!)
                  : null,
              duration: service.duration,
            );
            audioHandler.mediaItem.add(item);
            audioHandler.playbackState.add(
  PlaybackState(
    controls: [
      MediaControl.skipToPrevious,
      service.isPlaying ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
    ],
    systemActions: const {
      MediaAction.seek,
      MediaAction.seekForward,
      MediaAction.seekBackward,
    },
    androidCompactActionIndices: const [0, 1, 2],
    processingState: AudioProcessingState.ready,
    playing: service.isPlaying,
    updatePosition: service.position,
    bufferedPosition: service.duration,
    speed: 1.0,
  ),
);
          }
        });

        return service;
      },
      child: MaterialApp(
        title: 'SoundVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
