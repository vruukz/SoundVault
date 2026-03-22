import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SongTile({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onTap,
    this.onLongPress,
  });

  Color _color() {
    final colors = [
      AppTheme.accentGreen,
      const Color(0xFF60A5FA),
      const Color(0xFFF59E0B),
      const Color(0xFFA78BFA),
      const Color(0xFFF87171),
      const Color(0xFF34D399),
    ];
    return colors[song.id.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPlaying
              ? AppTheme.accentGreen.withOpacity(0.06)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPlaying
                ? AppTheme.accentGreen.withOpacity(0.3)
                : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            // Album art / playing indicator
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isPlaying ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: color.withOpacity(isPlaying ? 0.5 : 0.2)),
                  ),
                  child: Center(
                    child: isPlaying
                        ? _PlayingBars(color: AppTheme.accentGreen)
                        : Text(
                            song.title.isNotEmpty
                                ? song.title[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: color,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
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
                    style: TextStyle(
                      color: isPlaying
                          ? AppTheme.accentGreen
                          : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              song.durationFormatted,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _PlayingBars extends StatefulWidget {
  final Color color;
  const _PlayingBars({required this.color});

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final heights = [0.4, 1.0, 0.6];
          final offsets = [0.0, 0.3, 0.6];
          final t = (_controller.value + offsets[i]) % 1.0;
          final h = (heights[i] * (0.4 + 0.6 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0))) * 20;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 3,
              height: h.clamp(4.0, 20.0),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
