import 'package:flutter/material.dart';

Widget buildVideoEmbed({required String url, required String poster}) {
  return const ColoredBox(
    color: Color(0xFF12110F),
    child: Center(
      child: Text(
        'Videobanner vises i nettleseren',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}

Widget buildSpotifyEmbed({required String url}) {
  return const ColoredBox(
    color: Color(0xFF12110F),
    child: Center(
      child: Text(
        'Spotify-spiller vises i nettleseren',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}
