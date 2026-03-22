import 'package:audio_session/audio_session.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

enum RepeatMode { none, all, one }
enum VisualizerMode { bars, waveform, radial }

class PlayerService extends ChangeNotifier {
  static const _libraryKey = 'soundvault_library';

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

   double _volume = 0.8;          // ← add this
  double get volume => _volume;  // ← add this

  // Fake visualizer data — animated in the UI layer
  List<double> _visualizerData = List.filled(32, 0.0);
  final Random _random = Random();

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
    if (_isPlaying) _tickVisualizer();
    notifyListeners();
  });

  _player.durationStream.listen((dur) {
    _duration = dur ?? Duration.zero;
    notifyListeners();
  });

  _player.playingStream.listen((playing) {
    _isPlaying = playing;
    if (!playing) _resetVisualizer();
    notifyListeners();
  });

  _player.processingStateStream.listen((state) {
    if (state == ProcessingState.completed) {
      _onTrackComplete();
    }
  });
}

  void _tickVisualizer() {
    _visualizerData = List.generate(32, (i) {
      final base = sin(i * 0.4 + _position.inMilliseconds * 0.003) * 0.3 + 0.3;
      final noise = _random.nextDouble() * 0.4;
      return (base + noise).clamp(0.05, 1.0);
    });
  }

  void _resetVisualizer() {
    _visualizerData = List.generate(32, (i) =>
        sin(i * 0.4) * 0.05 + 0.05);
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
      notifyListeners();
    }
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _libraryKey, jsonEncode(_library.map((s) => s.toJson()).toList()));
  }

  Future<void> addSong(Song song) async {
    _library.add(song);
    await _saveLibrary();
    notifyListeners();
  }

  Future<void> removeSong(String id) async {
  // If removing currently playing song, stop first
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

  Future<void> clearLibrary() async {
  _library = [];
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_libraryKey);
  notifyListeners();
}

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
    _repeatMode = RepeatMode.values[
        (_repeatMode.index + 1) % RepeatMode.values.length];
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

  // Demo songs
  
}
