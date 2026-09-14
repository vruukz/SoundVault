import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../models/song.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';
import 'artist_screen.dart';
import 'album_screen.dart';
import 'playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _search = '';
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isScanning = false;

  // Songs tab multi-select mode
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // For swipe left/right on library
  double _dragStartX = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<PlayerService>();
      service.loadLibrary().then((_) {
        if (service.watchedFolder != null) {
          service.scanWatchedFolder();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg'],
      allowMultiple: true,
    );
    if (result == null) return;
    if (!mounted) return;
    final service = context.read<PlayerService>();
    int added = 0;
    for (final file in result.files) {
      if (file.path == null) continue;
      final song = Song(
        id: DateTime.now().millisecondsSinceEpoch.toString() + file.name,
        title: p.basenameWithoutExtension(file.name),
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        filePath: file.path!,
        duration: 0,
      );
      await service.addSong(song);
      added++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $added song${added != 1 ? 's' : ''}'),
          backgroundColor: AppTheme.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
        ),
      );
    }
  }

  Future<void> _pickWatchedFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    if (!mounted) return;
    final service = context.read<PlayerService>();
    setState(() => _isScanning = true);
    await service.setWatchedFolder(result);
    setState(() => _isScanning = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Watching: $result'),
          backgroundColor: AppTheme.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
        ),
      );
    }
  }

  Future<void> _rescanFolder() async {
    final service = context.read<PlayerService>();
    if (service.watchedFolder == null) return;
    setState(() => _isScanning = true);
    await service.scanWatchedFolder();
    setState(() => _isScanning = false);
  }

  void _showLibrarySettings(BuildContext context) {
    final service = context.read<PlayerService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LIBRARY SETTINGS',
                style: TextStyle(
                  color: AppTheme.accentGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              if (service.watchedFolder != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_rounded,
                          color: AppTheme.accentGreen, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          service.watchedFolder!,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (service.watchedFolder != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.accentGreen),
                        )
                      : const Icon(Icons.refresh_rounded,
                          color: AppTheme.accentGreen),
                  title: const Text('Rescan folder',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  onTap: _isScanning
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _rescanFolder();
                        },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_open_rounded,
                    color: AppTheme.textSecondary),
                title: Text(
                  service.watchedFolder != null
                      ? 'Change watched folder'
                      : 'Set watched folder',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickWatchedFolder();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.audio_file_outlined,
                    color: AppTheme.textSecondary),
                title: const Text('Add individual files',
                    style: TextStyle(color: AppTheme.textSecondary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _addFiles();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
  }

  // ── Selection mode (Songs tab) ───────────────────────────────────────

  void _enterSelectionMode(String firstId) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(firstId);
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  // ── Delete confirmation ───────────────────────────────────────────────

  void _confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(message,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFF87171), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAlbum(
      BuildContext context, PlayerService service, String album, List<Song> songs) {
    _confirmDelete(
      context,
      title: 'Delete album?',
      message:
          'This removes "$album" (${songs.length} song${songs.length != 1 ? 's' : ''}) from your library. The files on disk are not affected.',
      onConfirm: () => service.removeSongs(songs.map((s) => s.id)),
    );
  }

  void _confirmDeleteArtist(
      BuildContext context, PlayerService service, String artist, List<Song> songs) {
    _confirmDelete(
      context,
      title: 'Delete artist?',
      message:
          'This removes everything by "$artist" (${songs.length} song${songs.length != 1 ? 's' : ''}) from your library. The files on disk are not affected.',
      onConfirm: () => service.removeSongs(songs.map((s) => s.id)),
    );
  }

  void _confirmDeleteSelected(BuildContext context, PlayerService service) {
    final count = _selectedIds.length;
    _confirmDelete(
      context,
      title: 'Delete $count song${count != 1 ? 's' : ''}?',
      message:
          'This removes the selected song${count != 1 ? 's' : ''} from your library. The files on disk are not affected.',
      onConfirm: () {
        service.removeSongs(_selectedIds);
        _exitSelectionMode();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, service, _) {
        final songs = service.library
            .where((s) =>
                _search.isEmpty ||
                s.title.toLowerCase().contains(_search.toLowerCase()) ||
                s.artist.toLowerCase().contains(_search.toLowerCase()))
            .toList()
          ..sort((a, b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()));

        return GestureDetector(
          onHorizontalDragStart: (d) => _dragStartX = d.globalPosition.dx,
          onHorizontalDragEnd: (d) {
            if (_selectionMode) return;
            final dx = d.globalPosition.dx - _dragStartX;
            if (dx < -60) {
              // swipe left = next tab
              setState(() => _tab = (_tab + 1).clamp(0, 3));
            } else if (dx > 60) {
              // swipe right = prev tab
              setState(() => _tab = (_tab - 1).clamp(0, 3));
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.bgColor,
            body: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(service),
                      _buildTabBar(),
                      if (_tab == 0) _buildSongList(songs, service),
                      if (_tab == 1) _buildAlbumGrid(service),
                      if (_tab == 2) _buildArtistList(service),
                      if (_tab == 3) _buildPlaylistList(service),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
                if (service.currentSong != null)
                  GestureDetector(
                    onVerticalDragEnd: (d) {
                      // Swipe up on mini player = open player screen
                      if (d.primaryVelocity != null &&
                          d.primaryVelocity! < -200) {
                        _openPlayer(context);
                      }
                    },
                    child: MiniPlayer(onTap: () => _openPlayer(context)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(PlayerService service) {
    if (_selectionMode) {
      return SliverAppBar(
        floating: true,
        backgroundColor: AppTheme.bgColor,
        titleSpacing: 4,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          '${_selectedIds.length} selected',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFF87171)),
            onPressed: _selectedIds.isEmpty
                ? null
                : () => _confirmDeleteSelected(context, service),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      );
    }

    return SliverAppBar(
      floating: true,
      backgroundColor: AppTheme.bgColor,
      titleSpacing: 20,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search songs, artists...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _search = v),
            )
          : const Text(
              'SoundVault',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.search_rounded,
            color: AppTheme.textSecondary,
          ),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _search = '';
              }
            });
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.borderColor),
      ),
    );
  }

  SliverToBoxAdapter _buildTabBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Tab(
                        label: 'SONGS',
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0)),
                    const SizedBox(width: 8),
                    _Tab(
                        label: 'ALBUMS',
                        selected: _tab == 1,
                        onTap: () {
                          _exitSelectionMode();
                          setState(() => _tab = 1);
                        }),
                    const SizedBox(width: 8),
                    _Tab(
                        label: 'ARTISTS',
                        selected: _tab == 2,
                        onTap: () {
                          _exitSelectionMode();
                          setState(() => _tab = 2);
                        }),
                    const SizedBox(width: 8),
                    _Tab(
                        label: 'PLAYLISTS',
                        selected: _tab == 3,
                        onTap: () {
                          _exitSelectionMode();
                          setState(() => _tab = 3);
                        }),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showLibrarySettings(context),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Icon(Icons.settings_rounded,
                    color: AppTheme.textMuted, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongList(List<Song> songs, PlayerService service) {
    if (songs.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_off_rounded,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              const Text('No songs yet',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickWatchedFolder,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppTheme.accentGreen.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_rounded,
                          color: AppTheme.accentGreen, size: 16),
                      SizedBox(width: 8),
                      Text('Pick a folder',
                          style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _addFiles,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          color: AppTheme.textSecondary, size: 16),
                      SizedBox(width: 8),
                      Text('Add individual files',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final song = songs[i];
            final selected = _selectedIds.contains(song.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SongTile(
                song: song,
                isPlaying: service.currentSong?.id == song.id &&
                    service.isPlaying,
                selectionMode: _selectionMode,
                selected: selected,
                onTap: () {
                  if (_selectionMode) {
                    _toggleSelected(song.id);
                    return;
                  }
                  service.playSong(song, queue: songs);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlayerScreen()),
                  );
                },
                onLongPress: () {
                  if (_selectionMode) {
                    _toggleSelected(song.id);
                  } else {
                    _enterSelectionMode(song.id);
                  }
                },
                onMoreTap: _selectionMode
                    ? null
                    : () => _showSongMenu(context, song, service),
              ),
            );
          },
          childCount: songs.length,
        ),
      ),
    );
  }

  Widget _buildAlbumGrid(PlayerService service) {
    final albums = <String, List<Song>>{};
    for (final s in service.library) {
      albums.putIfAbsent(s.album, () => []).add(s);
    }
    final albumList = albums.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final entry = albumList[i];
            final color = _itemColor(entry.key);
            final coverSong = entry.value.firstWhere(
                (s) => s.albumArtPath != null,
                orElse: () => entry.value.first);

            return GestureDetector(
              onTap: () {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => AlbumScreen(
      album: entry.key,
      songs: entry.value,
    ),
  ));
},
              onLongPress: () =>
                  _confirmDeleteAlbum(context, service, entry.key, entry.value),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: coverSong.albumArtPath != null
                          ? _isNetworkUrl(coverSong.albumArtPath!)
                              ? Image.network(coverSong.albumArtPath!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _albumIcon(color))
                              : Image.file(
                                  File(coverSong.albumArtPath!),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _albumIcon(color))
                          : _albumIcon(color),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text('${entry.value.length} tracks',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            );
          },
          childCount: albumList.length,
        ),
      ),
    );
  }

  Widget _albumIcon(Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(Icons.album_rounded, color: color, size: 28),
    );
  }

  Widget _buildArtistList(PlayerService service) {
    final artists = <String, List<Song>>{};
    // New — strip featured artists
for (final s in service.library) {
  final mainArtist = s.artist
      .split(RegExp(r'\s*(;|,|\s+feat\.?|\s+ft\.?|\s+featuring|\s+&)\s*', caseSensitive: false))
      .first
      .trim();
  artists.putIfAbsent(mainArtist, () => []).add(s);
}
    final artistList = artists.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final entry = artistList[i];
            final color = _itemColor(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => ArtistScreen(
      artist: entry.key,
      songs: entry.value,
    ),
  ));
},
                onLongPress: () =>
                    _confirmDeleteArtist(context, service, entry.key, entry.value),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.1),
    shape: BoxShape.circle,
    border: Border.all(color: color.withValues(alpha: 0.3)),
  ),
  child: ClipOval(
    child: () {
      final coverSong = entry.value.firstWhere(
        (s) => s.albumArtPath != null,
        orElse: () => entry.value.first,
      );
      final art = coverSong.albumArtPath;
      if (art != null) {
        if (_isNetworkUrl(art)) {
          return Image.network(art,
              width: 44, height: 44, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ));
        } else {
          return Image.file(File(art),
              width: 44, height: 44, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ));
        }
      }
      return Center(
        child: Text(
          entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      );
    }(),
  ),
),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text('${entry.value.length} songs',
                                style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: artistList.length,
        ),
      ),
    );
  }

  // ── Playlists tab ────────────────────────────────────────────────────

  void _createPlaylist(BuildContext context, PlayerService service) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('New playlist',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
          onSubmitted: (v) {
            final name = v.trim();
            if (name.isNotEmpty) {
              service.createPlaylist(name);
              Navigator.pop(ctx);
            }
          },
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
                service.createPlaylist(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create',
                style: TextStyle(
                    color: AppTheme.accentGreen, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistList(PlayerService service) {
    final playlists = [...service.playlists]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _createPlaylist(context, service),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.accentGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded,
                            color: AppTheme.accentGreen, size: 18),
                        SizedBox(width: 10),
                        Text('New playlist',
                            style: TextStyle(
                                color: AppTheme.accentGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            }
            final playlist = playlists[i - 1];
            final songCount = playlist.songIds.length;
            final color = _itemColor(playlist.name);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistScreen(playlistId: playlist.id),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.queue_music_rounded,
                            color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(playlist.name,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text('$songCount song${songCount != 1 ? 's' : ''}',
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: playlists.length + 1,
        ),
      ),
    );
  }

  void _showSongMenu(BuildContext context, Song song, PlayerService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(song.title,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            Text('${song.artist} · ${song.album}',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderColor),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_rounded,
                  color: AppTheme.accentGreen),
              title: const Text('Play',
                  style: TextStyle(color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                service.playSong(song, queue: service.library);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PlayerScreen()));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.skip_next_rounded,
                  color: AppTheme.textSecondary),
              title: const Text('Play next',
                  style: TextStyle(color: AppTheme.textSecondary)),
              onTap: () {
                service.playNext(song);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${song.title}" will play next'),
                    backgroundColor: AppTheme.cardColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.playlist_add_rounded,
                  color: AppTheme.textSecondary),
              title: const Text('Add to playlist',
                  style: TextStyle(color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistSheet(context, song, service);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline_rounded,
                  color: AppTheme.textSecondary),
              title: const Text('Song info',
                  style: TextStyle(color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppTheme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                    title: const Text('Song Info',
                        style: TextStyle(color: AppTheme.textPrimary)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Title', song.title),
                        _infoRow('Artist', song.artist),
                        _infoRow('Album', song.album),
                        _infoRow('Duration', song.durationFormatted),
                        _infoRow('File', song.filePath.split(r'\').last),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK',
                            style: TextStyle(color: AppTheme.accentGreen)),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFF87171)),
              title: const Text('Remove from library',
                  style: TextStyle(color: Color(0xFFF87171))),
              onTap: () {
                service.removeSong(song.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(
      BuildContext context, Song song, PlayerService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      builder: (_) {
        final playlists = [...service.playlists]
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ADD TO PLAYLIST',
                  style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_rounded,
                      color: AppTheme.accentGreen),
                  title: const Text('New playlist',
                      style: TextStyle(
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(context);
                    final controller = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppTheme.borderColor),
                        ),
                        title: const Text('New playlist',
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
                            onPressed: () =>
                                Navigator.pop(ctx, controller.text.trim()),
                            child: const Text('Create',
                                style: TextStyle(
                                    color: AppTheme.accentGreen,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                    if (name != null && name.isNotEmpty) {
                      final playlist = await service.createPlaylist(name);
                      await service.addSongToPlaylist(playlist.id, song.id);
                    }
                  },
                ),
                if (playlists.isNotEmpty) ...[
                  const Divider(color: AppTheme.borderColor),
                  ...playlists.map((playlist) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.queue_music_rounded,
                            color: AppTheme.textSecondary),
                        title: Text(playlist.name,
                            style: const TextStyle(
                                color: AppTheme.textSecondary)),
                        trailing: playlist.songIds.contains(song.id)
                            ? const Icon(Icons.check_rounded,
                                color: AppTheme.accentGreen, size: 18)
                            : null,
                        onTap: () {
                          service.addSongToPlaylist(playlist.id, song.id);
                          Navigator.pop(context);
                        },
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text('$label:',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  bool _isNetworkUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  Color _itemColor(String key) {
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
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentGreen.withValues(alpha: 0.12)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? AppTheme.accentGreen : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.accentGreen : AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
