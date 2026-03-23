import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../visualizers/visualizer_widget.dart';
import '../services/player_service.dart';
import '../services/player_service.dart' as ps;

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, service, _) {
        final song = service.currentSong;
        if (song == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: AppTheme.bgColor,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, service),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildAlbumArt(song),
                        const SizedBox(height: 24),
                        _buildSongInfo(song, service),
                        const SizedBox(height: 24),
                        _buildSeekBar(service),
                        const SizedBox(height: 20),
                        _buildControls(service),
                        const SizedBox(height: 28),
                        _buildVisualizerSection(service),
                        const SizedBox(height: 24),
                        _buildVolumeBar(service),
                        const SizedBox(height: 32),
                        _buildQueue(context, service),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, PlayerService service) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textPrimary, size: 20),
            ),
          ),
          const Spacer(),
          const Text(
            'NOW PLAYING',
            style: TextStyle(
              color: AppTheme.accentGreen,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Icon(Icons.more_horiz_rounded,
                color: AppTheme.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(dynamic song) {
  final color = _songColor(song.id);
  final art = song.albumArtPath as String?;

  return Container(
    width: 200,
    height: 200,
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.25), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.15),
          blurRadius: 40,
          spreadRadius: 5,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: art != null
          ? (art.startsWith('http://') || art.startsWith('https://'))
              ? Image.network(art, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildInitials(song, color))
              : Image.file(File(art), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildInitials(song, color))
          : _buildInitials(song, color),
    ),
  );
}

Widget _buildInitials(dynamic song, Color color) {
  return Container(
    color: color.withOpacity(0.08),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          (song.title as String)
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0] : '')
              .join()
              .toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            'AUDIO',
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSongInfo(song, PlayerService service) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${song.artist} · ${song.album}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Shuffle & repeat mini controls
        GestureDetector(
          onTap: service.toggleShuffle,
          child: Icon(
            Icons.shuffle_rounded,
            color: service.isShuffle ? AppTheme.accentGreen : AppTheme.textMuted,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: service.toggleRepeat,
          child: Icon(
            service.repeatMode == ps.RepeatMode.one
    ? Icons.repeat_one_rounded
    : Icons.repeat_rounded,
color: service.repeatMode != ps.RepeatMode.none
                ? AppTheme.accentGreen
                : AppTheme.textMuted,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildSeekBar(PlayerService service) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            thumbColor: AppTheme.accentGreen,
            activeTrackColor: AppTheme.accentGreen,
            inactiveTrackColor: AppTheme.borderColor,
            overlayColor: const Color(0x334ADE80),
          ),
          child: Slider(
            value: service.progress.clamp(0.0, 1.0),
            onChanged: service.seekTo,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(service.position),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              Text(
                _formatDuration(service.duration),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(PlayerService service) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: Icons.skip_previous_rounded,
          size: 32,
          onTap: service.skipPrev,
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: service.togglePlay,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGreen.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              service.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppTheme.bgColor,
              size: 34,
            ),
          ),
        ),
        const SizedBox(width: 20),
        _ControlBtn(
          icon: Icons.skip_next_rounded,
          size: 32,
          onTap: service.skipNext,
        ),
      ],
    );
  }

  Widget _buildVisualizerSection(PlayerService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: const VisualizerWidget(height: 140),
    );
  }

  Widget _buildVolumeBar(PlayerService service) {
  return Consumer<PlayerService>(
    builder: (context, svc, _) => Row(
      children: [
        const Icon(Icons.volume_mute_rounded,
            color: AppTheme.textMuted, size: 18),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: SliderComponentShape.noOverlay,
              thumbColor: AppTheme.textSecondary,
              activeTrackColor: AppTheme.textSecondary,
              inactiveTrackColor: AppTheme.borderColor,
            ),
            child: Slider(
              value: svc.volume,
              onChanged: svc.setVolume,
            ),
          ),
        ),
        const Icon(Icons.volume_up_rounded,
            color: AppTheme.textMuted, size: 18),
      ],
    ),
  );
}

  Widget _buildQueue(BuildContext context, PlayerService service) {
    if (service.queue.isEmpty) return const SizedBox.shrink();
    final upcoming = service.queue
        .skip(service.currentIndex + 1)
        .take(5)
        .toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'UP NEXT',
          style: TextStyle(
            color: AppTheme.accentGreen,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...upcoming.map((song) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GestureDetector(
            onTap: () => service.playSong(song, queue: service.queue),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.music_note_rounded,
                      color: AppTheme.textMuted, size: 14),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      song.title,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    song.durationFormatted,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _songColor(String id) {
    final colors = [
      AppTheme.accentGreen,
      const Color(0xFF60A5FA),
      const Color(0xFFF59E0B),
      const Color(0xFFA78BFA),
      const Color(0xFFF87171),
      const Color(0xFF34D399),
    ];
    return colors[id.hashCode.abs() % colors.length];
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _ControlBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: size),
      ),
    );
  }
}
