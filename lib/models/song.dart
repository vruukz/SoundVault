class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final String filePath;
  final int duration; // milliseconds
  final String? albumArtPath;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.genre = 'Unknown Genre',
    required this.filePath,
    required this.duration,
    this.albumArtPath,
  });

  Song copyWith({String? genre}) => Song(
    id: id,
    title: title,
    artist: artist,
    album: album,
    genre: genre ?? this.genre,
    filePath: filePath,
    duration: duration,
    albumArtPath: albumArtPath,
  );

  String get durationFormatted {
    final total = Duration(milliseconds: duration);
    final m = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'genre': genre,
    'filePath': filePath,
    'duration': duration,
    'albumArtPath': albumArtPath,
  };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
    id: j['id'],
    title: j['title'],
    artist: j['artist'],
    album: j['album'],
    genre: j['genre'] ?? 'Unknown Genre',
    filePath: j['filePath'],
    duration: j['duration'],
    albumArtPath: j['albumArtPath'],
  );
}
