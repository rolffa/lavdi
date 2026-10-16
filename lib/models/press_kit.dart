import 'dart:typed_data';

import '../core/errors.dart';

class PressPhoto {
  const PressPhoto({
    required this.slot,
    required this.path,
    this.publicUrl = '',
    this.bytes,
    this.contentType = 'image/jpeg',
  });

  final int slot;
  final String path;
  final String publicUrl;
  final Uint8List? bytes;
  final String contentType;

  String get filename {
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    return 'presse-$slot.$extension';
  }
}

class PressKit {
  const PressKit({
    required this.artistId,
    required this.artistName,
    required this.slug,
    required this.bio,
    required this.spotifyUri,
    required this.photos,
  });

  final String artistId;
  final String artistName;
  final String slug;
  final String bio;
  final String spotifyUri;
  final List<PressPhoto?> photos;

  PressPhoto? photo(int slot) {
    if (slot < 1 || slot > photos.length) return null;
    return photos[slot - 1];
  }

  List<PressPhoto> get filled => [for (final photo in photos) ?photo];

  PressKit copyWith({
    String? bio,
    String? spotifyUri,
    List<PressPhoto?>? photos,
  }) {
    return PressKit(
      artistId: artistId,
      artistName: artistName,
      slug: slug,
      bio: bio ?? this.bio,
      spotifyUri: spotifyUri ?? this.spotifyUri,
      photos: photos ?? this.photos,
    );
  }

  static PressKit empty({
    required String artistId,
    required String artistName,
    required String slug,
    String spotifyUri = '',
  }) {
    return PressKit(
      artistId: artistId,
      artistName: artistName,
      slug: slug,
      bio: '',
      spotifyUri: spotifyUri,
      photos: const [null, null, null],
    );
  }
}

const pressPhotoMaxBytes = 20 * 1024 * 1024;

String? pressPhotoContentType(String filename) {
  final lower = filename.trim().toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  return null;
}

String pressPhotoExtension(String contentType) {
  return switch (contentType) {
    'image/png' => '.png',
    'image/webp' => '.webp',
    _ => '.jpg',
  };
}

PressPhoto checkedPressPhoto({
  required int slot,
  required String filename,
  required Uint8List bytes,
}) {
  if (slot < 1 || slot > 3) {
    throw PortalException('Velg pressebilde 1, 2 eller 3.');
  }
  final type = pressPhotoContentType(filename);
  if (type == null) {
    throw PortalException('Bruk PNG, JPG eller WebP.');
  }
  if (bytes.isEmpty) throw PortalException('Filen er tom.');
  if (bytes.length > pressPhotoMaxBytes) {
    throw PortalException('Pressebildet kan ikke være større enn 20 MB.');
  }
  return PressPhoto(
    slot: slot,
    path: '',
    contentType: type,
    bytes: bytes,
  );
}
