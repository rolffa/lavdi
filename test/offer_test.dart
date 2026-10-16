import 'package:amundsen_booking/core/errors.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final clock = DateTime(2026, 10, 12);

  test('artist approves an offer into a concert and the date locks', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.saveMyAvailability(dates: [DateTime(2026, 10, 24)], available: true);
    final open = await repository.fetchAvailability(
      artistId: DemoCatalog.linnId,
      from: DateTime(2026, 10, 24),
      to: DateTime(2026, 10, 24),
    );
    expect(open.single.isAvailable, isTrue);

    final offers = await repository.fetchMyOffers();
    expect(offers.single.venue, 'Parkteatret, Oslo');
    expect(offers.single.fee, 90000);

    final offer = offers.single;
    await repository.respondToOffer(offerId: offer.id, approve: true);

    expect(await repository.fetchMyOffers(), isEmpty);
    expect(
      (await repository.fetchMyGigs()).where((gig) => gig.organizer.venueCity == 'Parkteatret, Oslo'),
      isEmpty,
    );

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    await repository.confirmDeal(offer.id);

    final gigs = await repository.fetchMyGigs();
    expect(gigs.where((gig) => gig.organizer.venueCity == 'Parkteatret, Oslo'), isNotEmpty);

    final day = await repository.fetchAvailability(
      artistId: DemoCatalog.linnId,
      from: DateTime(2026, 10, 24),
      to: DateTime(2026, 10, 24),
    );
    expect(day.single.isAvailable, isFalse);
  });

  test('declining an offer requires a comment and can be undone', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    final before = (await repository.fetchMyGigs()).length;
    final offer = (await repository.fetchMyOffers()).single;
    expect(
      () => repository.respondToOffer(offerId: offer.id, approve: false),
      throwsA(isA<PortalException>()),
    );

    await repository.respondToOffer(
      offerId: offer.id,
      approve: false,
      comment: 'Opptatt den dagen.',
    );
    expect((await repository.fetchMyGigs()).length, before);
    final declined = await repository.fetchMyOffers();
    expect(declined.single.declined, isTrue);
    expect(declined.single.declineComment, 'Opptatt den dagen.');

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    final forAdmin = await repository.fetchDeclinedOffers();
    expect(forAdmin.single.artistName, 'Rolffa');
    expect(forAdmin.single.declineComment, 'Opptatt den dagen.');

    await repository.undoOfferDecline(offer.id);
    final pending = await repository.fetchMyOffers();
    expect(pending.single.pending, isTrue);
    expect(pending.single.declineComment, isEmpty);
    expect(await repository.fetchDeclinedOffers(), isEmpty);
  });

  test('booking manager sends an offer with the admin pin', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    expect(
      () => repository.signInAdmin(username: 'admin', password: 'feil'),
      throwsA(isA<PortalException>()),
    );

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    await repository.sendOffer(
      artistId: DemoCatalog.fjordId,
      date: DateTime(2026, 11, 7),
      fee: 95000,
      venue: 'Sentrum Scene',
      organizerName: 'Oslo Live',
      message: 'Kveldsspill.',
    );
    expect(
      () => repository.sendOffer(
        artistId: DemoCatalog.fjordId,
        date: DateTime(2026, 11, 7),
        fee: 95000,
        venue: 'Sentrum Scene',
        organizerName: 'Oslo Live',
        message: '',
      ),
      throwsA(isA<PortalException>()),
    );
  });
}
