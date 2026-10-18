import 'package:amundsen_booking/core/errors.dart';
import 'package:amundsen_booking/core/portal_scope.dart';
import 'package:amundsen_booking/core/theme.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/features/admin/admin_archive_page.dart';
import 'package:amundsen_booking/features/admin/admin_desk_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'demo_fixtures.dart';

void main() {
  test('confirmDeal can confirm a declined deal anyway', () async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 15));
    final seeded = await seedPendingOffer(
      repository,
      date: DateTime(2026, 11, 5),
    );
    final offerId = seeded.id;

    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.respondToOffer(
      offerId: offerId,
      approve: false,
      comment: 'vil ikke',
    );

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    await repository.confirmDeal(offerId);

    final confirmed =
        (await repository.fetchDeals()).singleWhere((deal) => deal.id == offerId);
    expect(confirmed.confirmed, isTrue);
    expect(confirmed.travelToken, isNotEmpty);
    expect(confirmed.crew, isNotEmpty);
  });

  test('archived declined offers disappear from the artist portal', () async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 15));
    final seeded = await seedPendingOffer(
      repository,
      date: DateTime(2026, 11, 6),
    );
    final offerId = seeded.id;

    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.respondToOffer(
      offerId: offerId,
      approve: false,
      comment: 'vil ikke',
    );
    expect(
      (await repository.fetchMyOffers()).any((offer) => offer.id == offerId),
      isTrue,
    );

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    await repository.archiveDeal(offerId);

    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    expect(
      (await repository.fetchMyOffers()).any((offer) => offer.id == offerId),
      isFalse,
    );
    expect(
      () => repository.undoOfferDecline(offerId),
      throwsA(isA<PortalException>()),
    );
  });

  test('unarchiveDeal restores declined deal to forespørsler', () async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 15));
    final seeded = await seedPendingOffer(
      repository,
      date: DateTime(2026, 11, 7),
    );
    final offerId = seeded.id;

    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.respondToOffer(
      offerId: offerId,
      approve: false,
      comment: 'vil ikke',
    );

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    await repository.archiveDeal(offerId);
    await repository.unarchiveDeal(offerId);

    final active = await repository.fetchDeals();
    final deal = active.singleWhere((item) => item.id == offerId);
    expect(deal.declined, isTrue);
    expect(deal.archived, isFalse);
    expect(await repository.fetchArchivedDeals(), isEmpty);

    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    expect(
      (await repository.fetchMyOffers()).any((offer) => offer.id == offerId),
      isTrue,
    );
  });

  test('archiveDeal moves declined deals out of forespørsler', () async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 15));
    final seeded = await seedPendingOffer(
      repository,
      date: DateTime(2026, 11, 8),
    );
    final offerId = seeded.id;

    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.respondToOffer(
      offerId: offerId,
      approve: false,
      comment: 'vil ikke',
    );

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    await repository.archiveDeal(offerId);

    final remaining = await repository.fetchDeals();
    expect(remaining.any((deal) => deal.id == offerId), isFalse);

    final archived = await repository.fetchArchivedDeals();
    expect(archived.single.id, offerId);
    expect(archived.single.archived, isTrue);
  });

  testWidgets('admin desk shows Arkiver and Arkiv link for declined deals', (
    tester,
  ) async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 15));
    final seeded = await seedPendingOffer(
      repository,
      date: DateTime(2026, 11, 9),
    );
    final offerId = seeded.id;

    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.respondToOffer(
      offerId: offerId,
      approve: false,
      comment: 'vil ikke',
    );

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );

    final router = GoRouter(
      initialLocation: '/admin',
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDeskPage(),
        ),
        GoRoute(
          path: '/admin/arkiv',
          builder: (context, state) => const AdminArchivePage(),
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
    await tester.pump();

    expect(find.text('Artist sa nei'), findsOneWidget);
    expect(find.text('Arkiver'), findsOneWidget);
    expect(find.text('Bekreft likevel'), findsOneWidget);
    expect(find.text('Arkiv'), findsOneWidget);

    await tester.ensureVisible(find.text('Arkiver'));
    await tester.tap(find.text('Arkiver'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Artist sa nei'), findsNothing);

    await tester.ensureVisible(find.text('Arkiv'));
    await tester.tap(find.text('Arkiv'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Arkiv'), findsWidgets);
    expect(find.text('Rolffa'), findsOneWidget);
    expect(find.text('Avslag: vil ikke'), findsOneWidget);
  });
}
