import 'package:supabase_flutter/supabase_flutter.dart';

class PortalException implements Exception {
  PortalException(this.message);

  final String message;

  @override
  String toString() => message;
}

String readableError(Object error) {
  if (error is PortalException) {
    final message = _sanitizeMessage(error.message);
    return message.isNotEmpty ? message : 'Noe gikk galt. Prøv igjen.';
  }
  if (error is PostgrestException) {
    final message = _sanitizeMessage(error.message);
    if (message.isNotEmpty) return message;
  }
  if (error is StorageException) {
    final message = _sanitizeMessage(error.message);
    if (message.isNotEmpty) return message;
  }
  if (error is AuthException) {
    final message = _sanitizeMessage(error.message);
    if (message.isNotEmpty) return message;
  }
  return 'Noe gikk galt. Prøv igjen.';
}

/// Avoid dumping HTML/JSON payloads (e.g. GitHub Pages 404/405) into the UI.
String _sanitizeMessage(String? raw) {
  final message = (raw ?? '').trim();
  if (message.isEmpty) return '';
  final lower = message.toLowerCase();
  if (lower.contains('<!doctype') ||
      lower.contains('<html') ||
      lower.contains('page not found') ||
      lower.contains('405 not allowed') ||
      lower.contains('404 not found') ||
      lower.contains('403 forbidden')) {
    return 'Kunne ikke nå serveren. Sjekk at nettsiden er oppdatert, eller prøv igjen.';
  }
  if (message.length > 280) return '${message.substring(0, 277)}…';
  return message;
}
