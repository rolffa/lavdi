import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/brand.dart';
import 'core/portal_scope.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/portal_repository.dart';

class PortalApp extends StatelessWidget {
  const PortalApp({
    super.key,
    required this.repository,
    required this.demoMode,
  });

  final PortalRepository repository;
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        return PortalScope(
          repository: repository,
          demoMode: demoMode,
          child: MaterialApp.router(
            title: Brand.name,
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            locale: const Locale('nb'),
            supportedLocales: const [Locale('nb'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: appRouter,
          ),
        );
      },
    );
  }
}

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Kunne ikke koble til Supabase.\n\n$details',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
