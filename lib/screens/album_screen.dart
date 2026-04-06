import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';

class AlbumScreen extends StatelessWidget {
  final String album;
  final List<Song> songs;

  const AlbumScreen({super.key, required this.album, required this.songs});

  bool _isNetworkUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  Color _albumColor() {
    final colors = [
      AppTheme.accentGreen,
      const Color(0xFF60A5FA),
      const Color(0xFFF59E0B),
      const Color(0xFFA78BFA),
      const Color(0xFFF87171),
      const Color(0xFF34D399),
    ];
    return colors[album.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _albumColor();
    final coverSong = songs.firstWhere(
      (s) => s.albumArtPath != null,
      orElse: () => songs.first,
    );
    final artist = songs.first.artist;

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
                expandedHeight: 220,
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
                        const SizedBox(height: 48),
                        // Album art
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: coverSong.albumArtPath != null
                              ? _isNetworkUrl(coverSong.albumArtPath!)
                                  ? Image.network(
                                      coverSong.albumArtPath!,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _fallbackArt(color),
                                    )
                                  : Image.file(
                                      File(coverSong.albumArtPath!),
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _fallbackArt(color),
                                    )
                              : _fallbackArt(color),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          album,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          artist,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        Text(
                          '${songs.length} track${songs.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 11),
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: AppTheme.accentGreen, size: 20),
                          SizedBox(width: 8),
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

  Widget _fallbackArt(Color color) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(Icons.album_rounded, color: color, size: 40),
    );
  }
}