import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/demo_portal_repository.dart';
import 'data/supabase_portal_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  await initializeDateFormatting('nb');

  final config = AppConfig.environment;
  if (!config.isConfigured) {
    runApp(PortalApp(repository: DemoPortalRepository(), demoMode: true));
    return;
  }

  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
    final client = Supabase.instance.client;
    if (await _artistsTableReady(client)) {
      runApp(
        PortalApp(
          repository: SupabasePortalRepository(client),
          demoMode: false,
        ),
      );
      return;
    }
    // Database mangler grunnschema (f.eks. public.artists). Kjør demomodus
    // så forsiden fungerer til schema.sql er kjørt i Supabase.
    runApp(PortalApp(repository: DemoPortalRepository(), demoMode: true));
  } catch (error) {
    runApp(StartupFailureApp(details: error.toString()));
  }
}

Future<bool> _artistsTableReady(SupabaseClient client) async {
  try {
    await client.from('artists').select('id').limit(1);
    return true;
  } on PostgrestException catch (error) {
    final code = error.code?.toUpperCase() ?? '';
    final message = error.message.toLowerCase();
    if (code == 'PGRST205' || message.contains('schema cache')) {
      return false;
    }
    // Andre feil (RLS, nettverk): la live-repo håndtere dem i UI.
    return true;
  } catch (_) {
    return true;
  }
}
