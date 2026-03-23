import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/player_service.dart';
import 'services/audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init audio_service — registers background service + notification
  final audioHandler = await AudioService.init(
    builder: () => SoundVaultAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.soundvault.audio',
      androidNotificationChannelName: 'SoundVault',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      notificationColor: Color(0xFF4ADE80),
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(SoundVaultApp(audioHandler: audioHandler));
}

class SoundVaultApp extends StatelessWidget {
  final SoundVaultAudioHandler audioHandler;
  const SoundVaultApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlayerService(audioHandler),
      child: MaterialApp(
        title: 'SoundVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
