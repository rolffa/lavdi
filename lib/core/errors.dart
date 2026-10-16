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
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  if (error is StorageException) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  return 'Noe gikk galt. Prøv igjen.';
}
