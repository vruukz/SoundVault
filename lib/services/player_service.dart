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
import '../models/song.dart';

enum RepeatMode { none, all, one }
enum VisualizerMode { bars, waveform, radial }

class PlayerService extends ChangeNotifier {
  static const _libraryKey = 'soundvault_library';
  static const _watchedFolderKey = 'soundvault_watched_folder';

  final SoLoud _soloud = SoLoud.instance;
  SoundHandle? _handle;
  AudioSource? _source;

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
  String? _watchedFolder;

  // FFT data
  AudioData? _audioData;

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
  double get volume => _volume;
  String? get watchedFolder => _watchedFolder;

  double get progress =>
      _duration.inMilliseconds > 0
          ? _position.inMilliseconds / _duration.inMilliseconds
          : 0.0;

  // Returns real FFT data (first 256 values) or wave (next 256)
  Float32List get fftData {
    if (_audioData == null) return Float32List(256);
    try {
      _audioData!.updateSamples();
      final samples = _audioData!.getAudioData();
      if (samples.length >= 256) {
        return samples.sublist(0, 256);
      }
    } catch (_) {}
    return Float32List(256);
  }

  Float32List get waveData {
    if (_audioData == null) return Float32List(256);
    try {
      final samples = _audioData!.getAudioData();
      if (samples.length >= 512) {
        return samples.sublist(256, 512);
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
        if (tag.title != null && tag.title!.isNotEmpty) result['title'] = tag.title!;
        if (tag.trackArtist != null && tag.trackArtist!.isNotEmpty) result['artist'] = tag.trackArtist!;
        if (tag.album != null && tag.album!.isNotEmpty) result['album'] = tag.album!;
        // FIX: removed unnecessary null check and ! on tag.duration (non-nullable int)
        result['duration'] = (tag.duration ?? 0) * 1000;
        if (tag.pictures.isNotEmpty) {
          final pic = tag.pictures.first;
          if (pic.bytes != null && pic.bytes!.isNotEmpty) {
            final coverPath = await _saveCoverArt(pic.bytes!, p.basenameWithoutExtension(filePath));
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
      final url = Uri.parse('https://itunes.apple.com/search?term=$query&media=music&limit=1');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
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
    // FIX: use ??= instead of if (x == null) x = ...
    String? coverPath = meta['coverPath'];
    coverPath ??= await _fetchCoverFromItunes(meta['title'], meta['artist']);
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
      await _stopInternal();
      _currentSong = null;
      _currentIndex = -1;
    }
    _library.removeWhere((s) => s.id == id);
    _queue.removeWhere((s) => s.id == id);
    await _saveLibrary();
    notifyListeners();
  }

  void playNext(Song song) {
    if (_queue.isEmpty) { _queue = [song]; return; }
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
        .where((e) => e is File && extensions.any((ext) => e.path.toLowerCase().endsWith(ext)))
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
        .where((s) => s.filePath.startsWith(_watchedFolder!) && !files.any((f) => f.path == s.filePath))
        .map((s) => s.id)
        .toList();
    // FIX: added curly braces around for-loop body
    for (final id in toRemove) {
      await removeSong(id);
    }
    notifyListeners();
  }

  // ── Playback ──────────────────────────────────────────────────────

  Future<void> _stopInternal() async {
    try {
      if (_handle != null) {
        await _soloud.stop(_handle!);
        _handle = null;
      }
      if (_source != null) {
        await _soloud.disposeSource(_source!);
        _source = null;
      }
    } catch (e) {
      debugPrint('Stop error: $e');
    }
    _isPlaying = false;
    _position = Duration.zero;
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    _queue = queue ?? _library;
    _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    if (_currentIndex == -1) {
      _queue = [song, ..._queue];
      _currentIndex = 0;
    }
    _currentSong = song;

    await _stopInternal();

    try {
      _source = await _soloud.loadFile(song.filePath);
      _handle = await _soloud.play(_source!, volume: _volume);

      // Poll position
      _pollPosition();

      _isPlaying = true;
    } catch (e) {
      debugPrint('Play error: $e');
    }
    notifyListeners();
  }

  void _pollPosition() async {
    while (_handle != null && _isPlaying) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (_handle == null) break;
      try {
        final pos = _soloud.getPosition(_handle!);
        final len = _soloud.getLength(_source!);
        _position = pos;
        _duration = len;

        // Check completion
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
    if (_handle == null) return;
    try {
      if (_isPlaying) {
        _soloud.setPause(_handle!, true);
        _isPlaying = false;
      } else {
        _soloud.setPause(_handle!, false);
        _isPlaying = true;
        _pollPosition();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('togglePlay error: $e');
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
    if (_handle == null || _source == null) return;
    try {
      final len = _soloud.getLength(_source!);
      final target = Duration(milliseconds: (len.inMilliseconds * progress).round());
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
    _repeatMode = RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  void setVisualizerMode(VisualizerMode mode) {
    _visualizerMode = mode;
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    _volume = v;
    if (_handle != null) {
      _soloud.setVolume(_handle!, v);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopInternal();
    _audioData?.dispose();
    _soloud.deinit();
    super.dispose();
  }
}
