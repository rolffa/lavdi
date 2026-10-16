String? spotifyEmbedUrl(String uri) {
  final value = uri.trim();
  if (value.isEmpty) return null;

  const params = 'utm_source=generator&theme=0';

  if (value.startsWith('https://open.spotify.com/embed/')) {
    if (value.contains('theme=')) return value;
    final join = value.contains('?') ? '&' : '?';
    return '$value$join$params';
  }

  if (value.startsWith('https://open.spotify.com/')) {
    final path = value
        .replaceFirst('https://open.spotify.com/', '')
        .split('?')
        .first
        .replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) return null;
    return 'https://open.spotify.com/embed/$path?$params';
  }

  final normalized = value.startsWith('spotify:')
      ? value.substring('spotify:'.length)
      : value;
  final parts = normalized
      .split(RegExp(r'[:/]'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) return null;

  const kinds = {'artist', 'album', 'playlist', 'track', 'episode', 'show'};
  if (!kinds.contains(parts[0])) return null;
  return 'https://open.spotify.com/embed/${parts[0]}/${parts[1]}?$params';
}

String? spotifyWebUrl(String uri) {
  final embed = spotifyEmbedUrl(uri);
  if (embed == null) return null;
  return embed.replaceFirst('/embed/', '/').split('?').first;
}
