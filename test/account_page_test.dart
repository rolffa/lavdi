import 'package:amundsen_booking/core/portal_scope.dart';
import 'package:amundsen_booking/core/theme.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/features/admin/admin_account_page.dart';
import 'package:amundsen_booking/features/artist_portal/artist_account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('admin konto page shows admin and artist sections', (tester) async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 15));
    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    final router = GoRouter(
      initialLocation: '/admin/konto',
      routes: [
        GoRoute(
          path: '/admin/konto',
          builder: (context, state) => const AdminAccountPage(),
        ),
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/min-side', builder: (context, state) => const SizedBox()),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initializeDateFormatting('nb');
    await tester.pumpWidget(
      PortalScope(
        repository: repository,
        demoMode: true,
        child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Adminkonto'), findsOneWidget);
    expect(find.text('Artistkonto'), findsOneWidget);
    expect(find.text('Endre passord'), findsOneWidget);
    expect(find.text('Send invitasjon'), findsOneWidget);
    expect(find.text('Send engangskode'), findsOneWidget);
  });

  testWidgets('artist konto page shows password and profile', (tester) async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 15));
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    final router = GoRouter(
      initialLocation: '/min-side/konto',
      routes: [
        GoRoute(
          path: '/min-side/konto',
          builder: (context, state) => const ArtistAccountPage(),
        ),
        GoRoute(path: '/min-side', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initializeDateFormatting('nb');
    await tester.pumpWidget(
      PortalScope(
        repository: repository,
        demoMode: true,
        child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Konto'), findsWidgets);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Passord'), findsOneWidget);
    expect(find.text('Endre passord'), findsOneWidget);
  });
}
