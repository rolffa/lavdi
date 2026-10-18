class ArtistSession {
  const ArtistSession({
    required this.artistId,
    required this.artistName,
    required this.email,
    this.asAdmin = false,
  });

  final String artistId;
  final String artistName;
  final String email;

  /// True when an admin opened this portal via «Se som artist».
  final bool asAdmin;
}
