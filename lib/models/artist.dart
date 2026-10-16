class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.tagline,
    required this.bio,
    required this.imageUrl,
    required this.videoUrl,
    required this.spotifyUri,
    required this.minPrice,
    this.published = true,
  });

  final String id;
  final String name;
  final String tagline;
  final String bio;
  final String imageUrl;
  final String videoUrl;
  final String spotifyUri;
  final int minPrice;
  final bool published;

  Artist copyWith({bool? published}) {
    return Artist(
      id: id,
      name: name,
      tagline: tagline,
      bio: bio,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      spotifyUri: spotifyUri,
      minPrice: minPrice,
      published: published ?? this.published,
    );
  }

  factory Artist.fromRow(Map<String, dynamic> row) {
    return Artist(
      id: row['id'] as String,
      name: row['navn'] as String,
      tagline: row['tagline'] as String,
      bio: row['bio'] as String,
      imageUrl: row['bilde_url'] as String,
      videoUrl: row['video_url'] as String,
      spotifyUri: row['spotify_uri'] as String? ?? '',
      minPrice: (row['minstepris'] as num).toInt(),
      published: row['publisert'] as bool? ?? true,
    );
  }
}
