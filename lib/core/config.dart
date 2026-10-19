class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  final String supabaseUrl;
  final String supabaseAnonKey;

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

  static final environment = AppConfig(
    supabaseUrl: normalizeSupabaseUrl(
      const String.fromEnvironment('SUPABASE_URL'),
    ),
    supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY').trim(),
  );
}
