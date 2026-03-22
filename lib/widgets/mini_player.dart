import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;
  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, service, _) {
        final song = service.currentSong;
        if (song == null) return const SizedBox.shrink();
        final color = _songColor(song.id);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Mini album art
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          song.title.isNotEmpty ? song.title[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            song.artist,
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => service.skipPrev(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.skip_previous_rounded,
                            color: AppTheme.textSecondary, size: 22),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => service.togglePlay(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          service.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppTheme.bgColor,
                          size: 20,
                        ),
                      ),
                    ),
                    
                        GestureDetector(
                          onTap: () => service.skipNext(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.skip_next_rounded,
                            color: AppTheme.textSecondary, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: service.progress,
                    backgroundColor: AppTheme.borderColor,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.accentGreen),
                    minHeight: 2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _songColor(String id) {
    final colors = [
      AppTheme.accentGreen,
      const Color(0xFF60A5FA),
      const Color(0xFFF59E0B),
      const Color(0xFFA78BFA),
      const Color(0xFFF87171),
    ];
    return colors[id.hashCode.abs() % colors.length];
  }
}
