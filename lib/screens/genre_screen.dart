import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';

class GenreScreen extends StatelessWidget {
  final String genre;
  final List<Song> songs;

  const GenreScreen({super.key, required this.genre, required this.songs});

  Color _genreColor() {
    final colors = [
      AppTheme.accentGreen,
      const Color(0xFF60A5FA),
      const Color(0xFFF59E0B),
      const Color(0xFFA78BFA),
      const Color(0xFFF87171),
      const Color(0xFF34D399),
    ];
    return colors[genre.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _genreColor();
    return Consumer<PlayerService>(
      builder: (context, service, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgColor,
          body: CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.bgColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                expandedHeight: 180,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.15),
                          AppTheme.bgColor,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: color.withValues(alpha: 0.4), width: 2),
                          ),
                          child: Center(
                            child: Icon(Icons.library_music_rounded,
                                color: color, size: 28),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          genre,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          songs.isEmpty
                              ? 'No songs yet'
                              : '${songs.length} song${songs.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: AppTheme.borderColor),
                ),
              ),

              // Play all button
              if (songs.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: GestureDetector(
                    onTap: () {
                      service.playSong(songs.first, queue: songs);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PlayerScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                AppTheme.accentGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: AppTheme.accentGreen, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'PLAY ALL',
                            style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Song list
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SongTile(
                        song: songs[i],
                        isPlaying: service.currentSong?.id == songs[i].id &&
                            service.isPlaying,
                        onTap: () {
                          service.playSong(songs[i], queue: songs);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PlayerScreen()),
                          );
                        },
                      ),
                    ),
                    childCount: songs.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
