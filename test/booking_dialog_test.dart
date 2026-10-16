import 'package:amundsen_booking/core/portal_scope.dart';
import 'package:amundsen_booking/core/theme.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/features/artist/booking_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Avbryt closes and send shows confirmation snackbar', (
    tester,
  ) async {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    await initializeDateFormatting('nb');
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 16));
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.saveMyAvailability(
      dates: [DateTime(2026, 11, 5)],
      available: true,
    );
    final artist = DemoCatalog.artists.firstWhere(
      (item) => item.id == DemoCatalog.linnId,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final sent = await showDialog<bool>(
                    context: context,
                    builder: (context) => BookingDialog(
                      artist: artist,
                      date: DateTime(2026, 11, 5),
                    ),
                  );
                  if (context.mounted && sent == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Forespørselen er sendt')),
                    );
                  }
                },
                child: const Text('Åpne'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      PortalScope(
        repository: repository,
        demoMode: true,
        child: MaterialApp.router(
          theme: buildTheme(),
          locale: const Locale('nb'),
          supportedLocales: const [Locale('nb'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Åpne'));
    await tester.pumpAndSettle();
    expect(find.text('Bookingforespørsel'), findsOneWidget);

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();
    expect(find.text('Bookingforespørsel'), findsNothing);

    await tester.tap(find.text('Åpne'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Scenehuset');
    await tester.enterText(fields.at(1), 'Scenehuset AS');
    await tester.enterText(fields.at(2), 'Kari Nord');
    await tester.enterText(fields.at(3), 'kari@scenehuset.no');
    await tester.enterText(fields.at(4), '90000000');
    await tester.enterText(fields.at(5), 'Parkteatret, Oslo');
    await tester.ensureVisible(find.text('Send forespørsel'));
    await tester.tap(find.text('Send forespørsel'));
    await tester.pumpAndSettle();

    expect(find.text('Bookingforespørsel'), findsNothing);
    expect(find.text('Lukk'), findsNothing);
    expect(find.text('Forespørselen er sendt'), findsOneWidget);
  });
}
