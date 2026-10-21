import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Resolve Flutter asset paths for HTML media elements on web.
String resolveMediaUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('blob:') ||
      trimmed.startsWith('data:')) {
    return trimmed;
  }
  // Project asset like assets/artist/foo.mp4 → /assets/assets/artist/foo.mp4
  final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  return 'assets/$path';
}

Widget buildVideoEmbed({required String url, required String poster}) {
  final src = resolveMediaUrl(url);
  final posterUrl = resolveMediaUrl(poster);
  return HtmlElementView.fromTagName(
    tagName: 'video',
    onElementCreated: (element) {
      final video = element as web.HTMLVideoElement;
      video
        ..src = src
        ..poster = posterUrl
        ..autoplay = true
        ..muted = true
        ..loop = true
        ..controls = true
        ..playsInline = true
        ..preload = 'auto';
      video.style
        ..setProperty('width', '100%')
        ..setProperty('height', '100%')
        ..setProperty('object-fit', 'cover')
        ..setProperty('background-color', '#12110F')
        ..setProperty('display', 'block');
    },
  );
}

Widget buildSpotifyEmbed({required String url}) {
  return HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final iframe = element as web.HTMLIFrameElement;
      iframe
        ..src = url
        ..title = 'Spotify'
        ..allow =
            'autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture'
        ..allowFullscreen = true
        ..loading = 'lazy'
        ..width = '100%'
        ..height = '100%';
      iframe.style
        ..setProperty('border', '0')
        ..setProperty('width', '100%')
        ..setProperty('height', '100%')
        ..setProperty('display', 'block');
    },
  );
}
