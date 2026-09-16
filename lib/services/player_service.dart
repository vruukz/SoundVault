import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audiotags/audiotags.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' as ja;
import '../models/song.dart';
import '../models/playlist.dart';

enum RepeatMode { none, all, one }
enum VisualizerMode { bars, waveform, radial }

class PlayerService extends ChangeNotifier {
  static const _libraryKey = 'soundvault_library';
  static const _watchedFolderKey = 'soundvault_watched_folder';
  static const _playlistsKey = 'soundvault_playlists';

  final SoLoud _soloud = SoLoud.instance;
  SoundHandle? _handle;
  AudioSource? _source;

  // FIX: SoLoud's bundled decoders only cover MP3/WAV/OGG/FLAC — no AAC/M4A
  // support. .m4a/.aac files were being scanned in (whitelist included them)
  // but silently failed to play. just_audio (already a dependency, but
  // unused) uses the platform's native decoder and handles AAC/M4A fine, so
  // it's used as a fallback engine for those formats.
  ja.AudioPlayer? _justAudioPlayer;
  bool _usingJustAudio = false;
  StreamSubscription<Duration>? _justAudioPositionSub;
  StreamSubscription<Duration?>? _justAudioDurationSub;
  StreamSubscription<ja.ProcessingState>? _justAudioStateSub;

  List<Song> _library = [];
  List<Playlist> _playlists = [];
  List<Song> _queue = [];
  Song? _currentSong;
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.none;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  VisualizerMode _visualizerMode = VisualizerMode.bars;
  double _volume = 0.8;
  String? _watchedFolder;

  // FIX: generation counter to cancel stale poll loops on skip/new song
  int _playGeneration = 0;

  // FIX: true from the moment a song transition starts (stop old source /
  // dispose it) until the new source is loaded and playing. The visualizer
  // ticker runs continuously and calls into SoLoud's native FFI on every
  // frame; if it queries audio data while a source is mid-dispose/mid-load,
  // it can hit freed native memory and hard-crash the process (not a
  // catchable Dart exception). Gating fftData/waveData on this flag closes
  // that window instead of racing the native engine.
  bool _isTransitioning = false;

  AudioData? _audioData;

  List<Song> get library => _library;
  List<Playlist> get playlists => _playlists;
  List<Song> get queue => _queue;
  Song? get currentSong => _currentSong;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  VisualizerMode get visualizerMode => _visualizerMode;
  double get volume => _volume;
  String? get watchedFolder => _watchedFolder;

  double get progress =>
      _duration.inMilliseconds > 0
          ? _position.inMilliseconds / _duration.inMilliseconds
          : 0.0;

  Float32List get fftData {
    if (_isTransitioning) return Float32List(256);
    // just_audio (used for AAC/M4A) doesn't feed SoLoud's analyzer, so
    // _audioData would just show a frozen leftover frame — return silence.
    if (_usingJustAudio) return Float32List(256);
    if (_audioData == null) return Float32List(256);
    try {
      _audioData!.updateSamples();
      final samples = _audioData!.getAudioData();
      if (samples.length >= 256) {
        return Float32List.fromList(samples.sublist(0, 256));
      }
    } catch (_) {}
    return Float32List(256);
  }

  // FIX: waveform uses FFT data mapped to [-1, 1] so the wave painter
  // sees proper positive/negative swing instead of flat/broken output
  Float32List get waveData {
    if (_isTransitioning) return Float32List(256);
    if (_usingJustAudio) return Float32List(256);
    if (_audioData == null) return Float32List(256);
    try {
      _audioData!.updateSamples();
      final samples = _audioData!.getAudioData();
      if (samples.isNotEmpty) {
        final len = samples.length.clamp(0, 256);
        final out = Float32List(256);
        for (int i = 0; i < len; i++) {
          out[i] = (samples[i] * 2.0 - 1.0).clamp(-1.0, 1.0);
        }
        return out;
      }
    } catch (_) {}
    return Float32List(256);
  }

  PlayerService() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _soloud.init(bufferSize: 1024);
      _soloud.setVisualizationEnabled(true);
      _soloud.setFftSmoothing(0.8);
      _audioData = AudioData(GetSamplesKind.linear);
    } catch (e) {
      debugPrint('SoLoud init error: $e');
    }
  }

  // ── Library ───────────────────────────────────────────────────────

  Future<void> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_libraryKey);
    if (data != null) {
      final list = jsonDecode(data) as List;
      _library = list.map((j) => Song.fromJson(j)).toList();
    }
    final playlistData = prefs.getString(_playlistsKey);
    if (playlistData != null) {
      final list = jsonDecode(playlistData) as List;
      _playlists = list.map((j) => Playlist.fromJson(j)).toList();
    }
    _watchedFolder = prefs.getString(_watchedFolderKey);
    notifyListeners();
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _libraryKey, jsonEncode(_library.map((s) => s.toJson()).toList()));
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistsKey,
        jsonEncode(_playlists.map((p) => p.toJson()).toList()));
  }

  // ── Playlists ─────────────────────────────────────────────────────

  List<Song> songsForPlaylist(Playlist playlist) {
    final byId = {for (final s in _library) s.id: s};
    return playlist.songIds
        .map((id) => byId[id])
        .whereType<Song>()
        .toList();
  }

  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    _playlists.add(playlist);
    await _savePlaylists();
    notifyListeners();
    return playlist;
  }

  Future<void> renamePlaylist(String id, String name) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index == -1) return;
    _playlists[index] = _playlists[index].copyWith(name: name);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    final playlist = _playlists[index];
    if (playlist.songIds.contains(songId)) return;
    _playlists[index] =
        playlist.copyWith(songIds: [...playlist.songIds, songId]);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    final playlist = _playlists[index];
    _playlists[index] = playlist.copyWith(
        songIds: playlist.songIds.where((id) => id != songId).toList());
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> clearLibrary() async {
    _library = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_libraryKey);
    notifyListeners();
  }

  Future<Map<String, dynamic>> _readMetadata(String filePath) async {
    final result = <String, dynamic>{
      'title': p.basenameWithoutExtension(filePath),
      'artist': 'Unknown Artist',
      'album': 'Unknown Album',
      'genre': 'Unknown Genre',
      'duration': 0,
      'coverPath': null,
    };
    try {
      final tag = await AudioTags.read(filePath);
      if (tag != null) {
        if (tag.title != null && tag.title!.isNotEmpty) result['title'] = tag.title!;
        if (tag.trackArtist != null && tag.trackArtist!.isNotEmpty) result['artist'] = tag.trackArtist!;
        if (tag.album != null && tag.album!.isNotEmpty) result['album'] = tag.album!;
        if (tag.genre != null && tag.genre!.isNotEmpty) result['genre'] = tag.genre!;
        result['duration'] = (tag.duration ?? 0) * 1000;
        if (tag.pictures.isNotEmpty) {
          final pic = tag.pictures.first;
          if (pic.bytes.isNotEmpty) {
            final coverPath = await _saveCoverArt(
                pic.bytes, p.basenameWithoutExtension(filePath));
            result['coverPath'] = coverPath;
          }
        }
      }
    } catch (e) {
      debugPrint('Metadata error: $e');
    }
    return result;
  }

  Future<String?> _saveCoverArt(Uint8List bytes, String songName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${dir.path}/covers');
      if (!await coversDir.exists()) await coversDir.create(recursive: true);
      final file = File('${coversDir.path}/$songName.jpg');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchCoverFromItunes(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$artist $title');
      final url = Uri.parse(
          'https://itunes.apple.com/search?term=$query&media=music&limit=1');
      final response =
          await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['resultCount'] > 0) {
          final artwork = data['results'][0]['artworkUrl100'] as String?;
          return artwork?.replaceAll('100x100bb', '600x600bb');
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> addSong(Song song) async {
    if (_library.any((s) => s.filePath == song.filePath)) return;
    final meta = await _readMetadata(song.filePath);
    String? coverPath = meta['coverPath'];
    coverPath ??= await _fetchCoverFromItunes(meta['title'], meta['artist']);
    final enriched = Song(
      id: song.id,
      title: meta['title'],
      artist: meta['artist'],
      album: meta['album'],
      genre: meta['genre'],
      filePath: song.filePath,
      duration: meta['duration'],
      albumArtPath: coverPath,
    );
    _library.add(enriched);
    await _saveLibrary();
    notifyListeners();
  }

  Future<void> removeSong(String id) async {
    if (_currentSong?.id == id) {
      await _stopInternal();
      _currentSong = null;
      _currentIndex = -1;
    }
    _library.removeWhere((s) => s.id == id);
    _queue.removeWhere((s) => s.id == id);
    _removeFromPlaylists({id});
    await _saveLibrary();
    notifyListeners();
  }

  // Bulk delete — used by album/artist long-press delete and the Songs tab
  // multi-select mode. Single _saveLibrary()/notifyListeners() call instead
  // of one per song.
  Future<void> removeSongs(Iterable<String> ids) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    if (_currentSong != null && idSet.contains(_currentSong!.id)) {
      await _stopInternal();
      _currentSong = null;
      _currentIndex = -1;
    }
    _library.removeWhere((s) => idSet.contains(s.id));
    _queue.removeWhere((s) => idSet.contains(s.id));
    _removeFromPlaylists(idSet);
    await _saveLibrary();
    notifyListeners();
  }

  void _removeFromPlaylists(Set<String> songIds) {
    for (var i = 0; i < _playlists.length; i++) {
      final playlist = _playlists[i];
      _playlists[i] = playlist.copyWith(
          songIds:
              playlist.songIds.where((id) => !songIds.contains(id)).toList());
    }
    _savePlaylists();
  }

  void playNext(Song song) {
    if (_queue.isEmpty) {
      _queue = [song];
      return;
    }
    final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, song);
    notifyListeners();
  }

  // ── Folder watching ───────────────────────────────────────────────

  Future<void> setWatchedFolder(String folderPath) async {
    _watchedFolder = folderPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_watchedFolderKey, folderPath);
    await scanWatchedFolder();
  }

  Future<void> scanWatchedFolder() async {
    if (_watchedFolder == null) return;
    final dir = Directory(_watchedFolder!);
    if (!await dir.exists()) return;
    const extensions = ['.mp3', '.flac', '.wav', '.aac', '.m4a', '.ogg'];
    final files = await dir
        .list(recursive: true)
        .where((e) =>
            e is File &&
            extensions.any((ext) => e.path.toLowerCase().endsWith(ext)))
        .cast<File>()
        .toList();

    for (final file in files) {
      if (!_library.any((s) => s.filePath == file.path)) {
        final song = Song(
          id: DateTime.now().millisecondsSinceEpoch.toString() + file.path,
          title: p.basenameWithoutExtension(file.path),
          artist: 'Unknown Artist',
          album: 'Unknown Album',
          filePath: file.path,
          duration: 0,
        );
        await addSong(song);
      }
    }

    final toRemove = _library
        .where((s) =>
            s.filePath.startsWith(_watchedFolder!) &&
            !files.any((f) => f.path == s.filePath))
        .map((s) => s.id)
        .toList();
    for (final id in toRemove) {
      await removeSong(id);
    }
    notifyListeners();
  }

  // ── Playback ──────────────────────────────────────────────────────

  Future<void> _stopInternal() async {
    try {
      if (_usingJustAudio) {
        await _justAudioStateSub?.cancel();
        await _justAudioPositionSub?.cancel();
        await _justAudioDurationSub?.cancel();
        await _justAudioPlayer?.stop();
      } else {
        if (_handle != null) {
          await _soloud.stop(_handle!);
          _handle = null;
        }
        if (_source != null) {
          await _soloud.disposeSource(_source!);
          _source = null;
        }
      }
    } catch (e) {
      debugPrint('Stop error: $e');
    }
    _isPlaying = false;
    _position = Duration.zero;
  }

  bool _needsJustAudio(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return ext == '.m4a' || ext == '.aac';
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    _isTransitioning = true;
    _queue = queue ?? _library;
    _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    if (_currentIndex == -1) {
      _queue = [song, ..._queue];
      _currentIndex = 0;
    }
    _currentSong = song;

    await _stopInternal();

    _usingJustAudio = _needsJustAudio(song.filePath);
    if (_usingJustAudio) {
      await _playWithJustAudio(song);
    } else {
      await _playWithSoLoud(song);
    }
  }

  Future<void> _playWithSoLoud(Song song) async {
    try {
      _source = await _soloud.loadFile(song.filePath);
      // FIX: in flutter_soloud 4.x, play() returns SoundHandle directly
      // (a synchronous FFI call) rather than Future<SoundHandle> — no await.
      _handle = _soloud.play(_source!, volume: _volume);

      // FIX: set _isPlaying = true BEFORE starting the poll loop.
      // Previously it was set after _pollPosition(), so the while loop
      // would see _isPlaying == false and exit immediately on first play.
      _isPlaying = true;
      _isTransitioning = false;
      notifyListeners();

      // Each play gets a unique generation; stale loops check and bail.
      final generation = ++_playGeneration;
      _pollPosition(generation);
    } catch (e) {
      debugPrint('Play error: $e');
      _isPlaying = false;
      _isTransitioning = false;
      notifyListeners();
    }
  }

  Future<void> _playWithJustAudio(Song song) async {
    try {
      _justAudioPlayer ??= ja.AudioPlayer();
      final player = _justAudioPlayer!;

      await player.setFilePath(song.filePath);
      await player.setVolume(_volume);

      _isPlaying = true;
      _isTransitioning = false;
      notifyListeners();

      final generation = ++_playGeneration;

      await _justAudioPositionSub?.cancel();
      _justAudioPositionSub = player.positionStream.listen((pos) {
        if (generation != _playGeneration) return;
        _position = pos;
        notifyListeners();
      });

      await _justAudioDurationSub?.cancel();
      _justAudioDurationSub = player.durationStream.listen((dur) {
        if (generation != _playGeneration || dur == null) return;
        _duration = dur;
        notifyListeners();
      });

      await _justAudioStateSub?.cancel();
      _justAudioStateSub = player.processingStateStream.listen((state) {
        if (generation != _playGeneration) return;
        if (state == ja.ProcessingState.completed) {
          _onTrackComplete();
        }
      });

      await player.play();
    } catch (e) {
      debugPrint('just_audio play error: $e');
      _isPlaying = false;
      _isTransitioning = false;
      notifyListeners();
    }
  }

  void _pollPosition(int generation) async {
    while (_handle != null && _isPlaying && generation == _playGeneration) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (_handle == null || generation != _playGeneration) break;
      try {
        final pos = _soloud.getPosition(_handle!);
        final len = _soloud.getLength(_source!);
        _position = pos;
        _duration = len;

        if (!_soloud.getIsValidVoiceHandle(_handle!)) {
          _onTrackComplete();
          break;
        }
        notifyListeners();
      } catch (_) {
        break;
      }
    }
  }

  void _onTrackComplete() {
    _isPlaying = false;
    switch (_repeatMode) {
      case RepeatMode.one:
        playSong(_currentSong!, queue: _queue);
        break;
      case RepeatMode.all:
        skipNext();
        break;
      case RepeatMode.none:
        if (_currentIndex < _queue.length - 1) {
          skipNext();
        } else {
          notifyListeners();
        }
    }
  }

  Future<void> togglePlay() async {
    if (_usingJustAudio) {
      if (_justAudioPlayer == null) return;
      try {
        if (_isPlaying) {
          await _justAudioPlayer!.pause();
          _isPlaying = false;
        } else {
          await _justAudioPlayer!.play();
          _isPlaying = true;
        }
        notifyListeners();
      } catch (e) {
        debugPrint('togglePlay error: $e');
      }
      return;
    }

    if (_handle == null) return;
    try {
      if (_isPlaying) {
        _soloud.setPause(_handle!, true);
        _isPlaying = false;
        notifyListeners();
      } else {
        _soloud.setPause(_handle!, false);
        _isPlaying = true;
        notifyListeners();
        // Resume polling with current generation
        _pollPosition(_playGeneration);
      }
    } catch (e) {
      debugPrint('togglePlay error: $e');
    }
  }

  // Pauses without toggling — used when the audio route disappears (e.g. a
  // Bluetooth speaker disconnects) so we never accidentally resume playback.
  Future<void> pause() async {
    if (!_isPlaying) return;
    if (_usingJustAudio) {
      if (_justAudioPlayer == null) return;
      try {
        await _justAudioPlayer!.pause();
        _isPlaying = false;
        notifyListeners();
      } catch (e) {
        debugPrint('pause error: $e');
      }
      return;
    }

    if (_handle == null) return;
    try {
      _soloud.setPause(_handle!, true);
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('pause error: $e');
    }
  }

  Future<void> skipNext() async {
    if (_queue.isEmpty) return;
    if (_isShuffle) {
      _currentIndex = Random().nextInt(_queue.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }
    await playSong(_queue[_currentIndex], queue: _queue);
  }

  Future<void> skipPrev() async {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 3) {
      await seekTo(0);
      return;
    }
    if (_isShuffle) {
      _currentIndex = Random().nextInt(_queue.length);
    } else {
      _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    }
    await playSong(_queue[_currentIndex], queue: _queue);
  }

  Future<void> seekTo(double progress) async {
    if (_usingJustAudio) {
      if (_justAudioPlayer == null) return;
      try {
        final target = Duration(
            milliseconds: (_duration.inMilliseconds * progress).round());
        await _justAudioPlayer!.seek(target);
        _position = target;
        notifyListeners();
      } catch (e) {
        debugPrint('Seek error: $e');
      }
      return;
    }

    if (_handle == null || _source == null) return;
    try {
      final len = _soloud.getLength(_source!);
      final target = Duration(
          milliseconds: (len.inMilliseconds * progress).round());
      _soloud.seek(_handle!, target);
      _position = target;
      notifyListeners();
    } catch (e) {
      debugPrint('Seek error: $e');
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _repeatMode =
        RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  void setVisualizerMode(VisualizerMode mode) {
    _visualizerMode = mode;
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    _volume = v;
    if (_usingJustAudio) {
      await _justAudioPlayer?.setVolume(v);
    } else if (_handle != null) {
      _soloud.setVolume(_handle!, v);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopInternal();
    _justAudioPlayer?.dispose();
    _audioData?.dispose();
    _soloud.deinit();
    super.dispose();
  }
}
