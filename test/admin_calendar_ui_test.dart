import 'package:amundsen_booking/core/portal_scope.dart';
import 'package:amundsen_booking/core/theme.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/features/admin/admin_calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('admin calendar loads and toggles a day', (tester) async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 15));
    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    final router = GoRouter(
      initialLocation: '/admin/kalender',
      routes: [
        GoRoute(
          path: '/admin/kalender',
          builder: (context, state) => const AdminCalendarPage(),
        ),
        GoRoute(path: '/admin/tilbud', builder: (context, state) => const SizedBox()),
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
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Tilgjengelighet'), findsOneWidget);
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(
      find.text(
        'Marker alle helger (fre–lør) som tilgjengelig denne måneden',
      ),
      findsOneWidget,
    );

    final day = find.text('20');
    expect(day, findsOneWidget);
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Lagret som ledig'), findsOneWidget);
  });
}
