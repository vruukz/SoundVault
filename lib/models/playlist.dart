class Playlist {
  final String id;
  final String name;
  final List<String> songIds;

  Playlist({
    required this.id,
    required this.name,
    List<String>? songIds,
  }) : songIds = songIds ?? [];

  Playlist copyWith({String? name, List<String>? songIds}) => Playlist(
        id: id,
        name: name ?? this.name,
        songIds: songIds ?? this.songIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songIds': songIds,
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'],
        name: j['name'],
        songIds: (j['songIds'] as List).map((e) => e as String).toList(),
      );
}
