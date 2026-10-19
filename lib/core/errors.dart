import 'package:supabase_flutter/supabase_flutter.dart';

class PortalException implements Exception {
  PortalException(this.message);

  final String message;

  @override
  String toString() => message;
}

String readableError(Object error) {
  if (error is PortalException) return error.message;
  if (error is PostgrestException) {
    final message = _sanitizeMessage(error.message);
    if (message.isNotEmpty) return message;
  }
  if (error is StorageException) {
    final message = _sanitizeMessage(error.message);
    if (message.isNotEmpty) return message;
  }
  return 'Noe gikk galt. Prøv igjen.';
}

/// Avoid dumping HTML/JSON payloads (e.g. GitHub Pages 404) into the UI.
String _sanitizeMessage(String? raw) {
  final message = (raw ?? '').trim();
  if (message.isEmpty) return '';
  final lower = message.toLowerCase();
  if (lower.contains('<!doctype') ||
      lower.contains('<html') ||
      lower.contains('page not found')) {
    return 'Kunne ikke hente data. Prøv igjen.';
  }
  if (message.length > 280) return '${message.substring(0, 277)}…';
  return message;
}
