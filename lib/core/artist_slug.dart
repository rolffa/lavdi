String artistSlug(String name) {
  final buffer = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(switch (char) {
      'æ' => 'a',
      'ø' => 'o',
      'å' => 'a',
      'é' => 'e',
      'á' => 'a',
      '&' => ' ',
      _ => char,
    });
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
