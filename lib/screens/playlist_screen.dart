import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';

class PlaylistScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistScreen({super.key, required this.playlistId});

  Color _color(String key) {
    final colors = [
      AppTheme.accentGreen,
      const Color(0xFF60A5FA),
      const Color(0xFFF59E0B),
      const Color(0xFFA78BFA),
      const Color(0xFFF87171),
      const Color(0xFF34D399),
    ];
    return colors[key.hashCode.abs() % colors.length];
  }

  bool _isNetworkUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  void _renamePlaylist(BuildContext context, PlayerService service, Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Rename playlist',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                service.renamePlaylist(playlist.id, name);
              }
              Navigator.pop(ctx);
            },
            child: Text('Save',
                style: TextStyle(
                    color: AppTheme.accentGreen, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _deletePlaylist(BuildContext context, PlayerService service, Playlist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Delete playlist?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('This removes "${playlist.name}". Songs stay in your library.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              service.deletePlaylist(playlist.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFF87171), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, service, _) {
        final playlist = service.playlists.firstWhere(
          (p) => p.id == playlistId,
          orElse: () => Playlist(id: playlistId, name: 'Playlist'),
        );
        final songs = service.songsForPlaylist(playlist);
        final color = _color(playlist.name);
        final coverSong = songs.isEmpty
            ? null
            : songs.firstWhere((s) => s.albumArtPath != null,
                orElse: () => songs.first);

        return Scaffold(
          backgroundColor: AppTheme.bgColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.bgColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppTheme.textSecondary),
                    onPressed: () => _renamePlaylist(context, service, playlist),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFF87171)),
                    onPressed: () => _deletePlaylist(context, service, playlist),
                  ),
                ],
                expandedHeight: 200,
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
                        if (songs.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: coverSong?.albumArtPath != null
                                ? _isNetworkUrl(coverSong!.albumArtPath!)
                                    ? Image.network(coverSong.albumArtPath!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _fallbackArt(color))
                                    : Image.file(File(coverSong.albumArtPath!),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _fallbackArt(color))
                                : _fallbackArt(color),
                          )
                        else
                          _fallbackArt(color),
                        const SizedBox(height: 12),
                        Text(
                          playlist.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
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
                              color: AppTheme.accentGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
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
              if (songs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.playlist_add_rounded,
                            size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        const Text('No songs in this playlist yet',
                            style:
                                TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Add songs from the song menu',
                            style:
                                TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Dismissible(
                          key: ValueKey(songs[i].id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF87171).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.remove_circle_outline,
                                color: Color(0xFFF87171)),
                          ),
                          onDismissed: (_) =>
                              service.removeSongFromPlaylist(playlist.id, songs[i].id),
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
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(Icons.queue_music_rounded, color: color, size: 36),
    );
  }
}
