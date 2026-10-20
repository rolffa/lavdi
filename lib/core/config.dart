class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.publicSiteUrl,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Canonical public origin for e-postlenker (invitasjon, magic link, reset).
  /// Never localhost — musicians open these on their own devices.
  final String publicSiteUrl;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Accepts full URL or bare project ref (`abcd1234` → `https://abcd1234.supabase.co`).
  static String normalizeSupabaseUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    }
    if (RegExp(r'^[a-z0-9]+$').hasMatch(value)) {
      return 'https://$value.supabase.co';
    }
    return value;
  }

  static String normalizeOrigin(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  /// Origin used in e-mails and shareable invite links.
  /// Prefers PUBLIC_SITE_URL; never falls back to localhost.
  static String resolvePublicSiteUrl({
    String fromEnvironment = '',
    String runtimeOrigin = '',
  }) {
    final configured = normalizeOrigin(fromEnvironment);
    if (configured.isNotEmpty) return configured;

    final origin = normalizeOrigin(runtimeOrigin);
    final host = Uri.tryParse(origin)?.host.toLowerCase() ?? '';
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host.endsWith('.local') ||
        origin.isEmpty) {
      return 'https://www.lavdi.no';
    }
    return origin;
  }

  static final environment = AppConfig(
    supabaseUrl: normalizeSupabaseUrl(
      const String.fromEnvironment('SUPABASE_URL'),
    ),
    supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY').trim(),
    publicSiteUrl: resolvePublicSiteUrl(
      fromEnvironment: const String.fromEnvironment('PUBLIC_SITE_URL'),
    ),
  );
}
