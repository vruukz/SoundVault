import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audiotags/audiotags.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

enum RepeatMode { none, all, one }
enum VisualizerMode { bars, waveform, radial }

class PlayerService extends ChangeNotifier {
  static const _libraryKey = 'soundvault_library';
  static const _watchedFolderKey = 'soundvault_watched_folder';

  final AudioPlayer _player = AudioPlayer();

  List<Song> _library = [];
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
  double get volume => _volume;
  String? _watchedFolder;
  String? get watchedFolder => _watchedFolder;

  // Visualizer — driven by position for sync
  List<double> _visualizerData = List.filled(32, 0.0);
  final Random _random = Random();
  double _vizPhase = 0.0;

  List<Song> get library => _library;
  List<Song> get queue => _queue;
  Song? get currentSong => _currentSong;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  VisualizerMode get visualizerMode => _visualizerMode;
  List<double> get visualizerData => _visualizerData;

  double get progress =>
      _duration.inMilliseconds > 0
          ? _position.inMilliseconds / _duration.inMilliseconds
          : 0.0;

  PlayerService() {
    _initPlayer().then((_) {});
  }

  Future<void> _initPlayer() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.positionStream.listen((pos) {
      _position = pos;
      if (_isPlaying) _tickVisualizer(pos);
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    _player.playingStream.listen((playing) {
      _isPlaying = playing;
      if (!playing) _decayVisualizer();
      notifyListeners();
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onTrackComplete();
      }
    });
  }

  // Visualizer driven by audio position — much better sync
  void _tickVisualizer(Duration pos) {
    final t = pos.inMilliseconds / 1000.0;
    _vizPhase = t;
    _visualizerData = List.generate(32, (i) {
      final freq = (i + 1) * 0.7;
      final wave1 = sin(t * freq + i * 0.3) * 0.35;
      final wave2 = sin(t * freq * 1.3 + i * 0.5) * 0.2;
      final wave3 = sin(t * 2.1 + i * 0.8) * 0.15;
      final noise = (_random.nextDouble() - 0.5) * 0.25;
      // Boost bass frequencies
      final bassBoost = i < 6 ? (0.2 * (6 - i) / 6) : 0.0;
      final val = 0.35 + wave1 + wave2 + wave3 + noise + bassBoost;
      return val.clamp(0.05, 1.0);
    });
  }

  void _decayVisualizer() {
    _visualizerData = List.generate(32, (i) =>
        (_visualizerData[i] * 0.3).clamp(0.0, 1.0));
  }

  void _onTrackComplete() {
    switch (_repeatMode) {
      case RepeatMode.one:
        _player.seek(Duration.zero);
        _player.play();
        break;
      case RepeatMode.all:
        skipNext();
        break;
      case RepeatMode.none:
        if (_currentIndex < _queue.length - 1) {
          skipNext();
        } else {
          _isPlaying = false;
          notifyListeners();
        }
    }
  }

  Future<void> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_libraryKey);
    if (data != null) {
      final list = jsonDecode(data) as List;
      _library = list.map((j) => Song.fromJson(j)).toList();
    }
    _watchedFolder = prefs.getString(_watchedFolderKey);
    notifyListeners();
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _libraryKey, jsonEncode(_library.map((s) => s.toJson()).toList()));
  }

  Future<void> clearLibrary() async {
    _library = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_libraryKey);
    notifyListeners();
  }

  // Read metadata from file using audiotags
  Future<Map<String, dynamic>> _readMetadata(String filePath) async {
    final result = <String, dynamic>{
      'title': p.basenameWithoutExtension(filePath),
      'artist': 'Unknown Artist',
      'album': 'Unknown Album',
      'duration': 0,
      'coverPath': null,
    };

    try {
      final tag = await AudioTags.read(filePath);
      if (tag != null) {
        if (tag.title != null && tag.title!.isNotEmpty) {
          result['title'] = tag.title!;
        }
        if (tag.trackArtist != null && tag.trackArtist!.isNotEmpty) {
          result['artist'] = tag.trackArtist!;
        }
        if (tag.album != null && tag.album!.isNotEmpty) {
          result['album'] = tag.album!;
        }
        if (tag.duration != null) {
          result['duration'] = tag.duration! * 1000; // to ms
        }

        // Extract embedded cover art
        if (tag.pictures.isNotEmpty) {
          final pic = tag.pictures.first;
          if (pic.bytes != null && pic.bytes!.isNotEmpty) {
            final coverPath = await _saveCoverArt(
                pic.bytes!, p.basenameWithoutExtension(filePath));
            result['coverPath'] = coverPath;
          }
        }
      }
    } catch (e) {
      debugPrint('Metadata read error for $filePath: $e');
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
    } catch (e) {
      debugPrint('Cover art save error: $e');
      return null;
    }
  }

  // Fallback: fetch cover from iTunes if no embedded art
  Future<String?> _fetchCoverFromItunes(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$artist $title');
      final url = Uri.parse(
          'https://itunes.apple.com/search?term=$query&media=music&limit=1');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['resultCount'] > 0) {
          final artwork = data['results'][0]['artworkUrl100'] as String?;
          return artwork?.replaceAll('100x100bb', '600x600bb');
        }
      }
    } catch (e) {
      debugPrint('iTunes fetch error: $e');
    }
    return null;
  }

  Future<void> addSong(Song song) async {
    // Check not already in library
    if (_library.any((s) => s.filePath == song.filePath)) return;

    // Read metadata from file
    final meta = await _readMetadata(song.filePath);
    String? coverPath = meta['coverPath'];

    // Fallback to iTunes if no embedded art
    if (coverPath == null) {
      coverPath = await _fetchCoverFromItunes(
          meta['title'], meta['artist']);
    }

    final enriched = Song(
      id: song.id,
      title: meta['title'],
      artist: meta['artist'],
      album: meta['album'],
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
      await _player.stop();
      _currentSong = null;
      _currentIndex = -1;
    }
    _library.removeWhere((s) => s.id == id);
    _queue.removeWhere((s) => s.id == id);
    await _saveLibrary();
    notifyListeners();
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

  // ── Folder watching ──────────────────────────────────────────────

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
            extensions.any((ext) =>
                e.path.toLowerCase().endsWith(ext)))
        .cast<File>()
        .toList();

    // Add new files not already in library
    int added = 0;
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
        added++;
      }
    }

    // Remove songs whose files no longer exist
    final toRemove = _library
        .where((s) =>
            s.filePath.startsWith(_watchedFolder!) &&
            !files.any((f) => f.path == s.filePath))
        .map((s) => s.id)
        .toList();
    for (final id in toRemove) {
      await removeSong(id);
    }

    debugPrint('Folder scan: $added added, ${toRemove.length} removed');
    notifyListeners();
  }

  // ── Playback ──────────────────────────────────────────────────────

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    _queue = queue ?? _library;
    _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    if (_currentIndex == -1) {
      _queue = [song, ..._queue];
      _currentIndex = 0;
    }
    _currentSong = song;
    try {
      await _player.setFilePath(song.filePath);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing: $e');
    }
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> skipNext() async {
    if (_queue.isEmpty) return;
    if (_isShuffle) {
      _currentIndex = _random.nextInt(_queue.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }
    await playSong(_queue[_currentIndex], queue: _queue);
  }

  Future<void> skipPrev() async {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_isShuffle) {
      _currentIndex = _random.nextInt(_queue.length);
    } else {
      _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    }
    await playSong(_queue[_currentIndex], queue: _queue);
  }

  Future<void> seekTo(double progress) async {
    final ms = (_duration.inMilliseconds * progress).round();
    await _player.seek(Duration(milliseconds: ms));
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
    await _player.setVolume(v);
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
