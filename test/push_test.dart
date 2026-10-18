import 'package:amundsen_booking/core/push_logic.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/models/booking_draft.dart';
import 'package:amundsen_booking/models/repertoire.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_fixtures.dart';

void main() {
  final clock = DateTime(2026, 10, 12);

  test('mail goes to the band leader only', () {
    final emails = bandLeaderEmails(const [
      (isLeader: true, role: 'Musiker', email: 'Rolffa@Lavdi.no'),
      (isLeader: false, role: 'Admin', email: 'admin@lavdi.no'),
      (isLeader: false, role: 'Bandleder', email: 'leder@lavdi.no'),
      (isLeader: false, role: 'Musiker', email: 'sigrid@lavdi.no'),
      (isLeader: false, role: 'Musiker', email: ''),
    ]);

    expect(emails, ['rolffa@lavdi.no', 'leder@lavdi.no']);
    expect(
      bookingPushBody(organizer: '', venue: 'USF Verftet', date: DateTime(2026, 10, 11)),
      'USF Verftet har sendt en forespørsel for 11.10.2026. Klikk for å se detaljer.',
    );
  });

  test('sending a deal to the artist addresses mail to the band leader', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.saveMyAvailability(
      dates: [DateTime(2026, 10, 20), DateTime(2026, 10, 21)],
      available: true,
    );
    await repository.submitBooking(_draft());
    expect(repository.mailOutbox, isEmpty);
    expect(repository.pushOutbox, isEmpty);

    await repository.submitBooking(_draft(day: 21));
    expect(repository.mailOutbox, isEmpty);
    expect(await repository.fetchBookingRequest('booking-2'), isNull);

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    final deals = await repository.fetchDeals();
    final inquiry = deals.singleWhere((deal) => deal.date.day == 21);
    await repository.sendDealToArtist(
      dealId: inquiry.id,
      fee: 80000,
      message: 'Avtalt pris.',
    );

    expect(repository.pushOutbox, isEmpty);
    expect(repository.mailOutbox, hasLength(1));
    final notice = repository.mailOutbox.single;
    expect(notice.to, DemoCatalog.artistEmail);
    expect(notice.subject, bookingPushTitle);
    expect(
      notice.body,
      'Oslo Live har sendt en forespørsel for 21.10.2026. Klikk for å se detaljer.',
    );
    expect(notice.url, '/min-side');

    await repository.signOutArtist();
    expect(await repository.fetchBookingRequest('booking-2'), isNull);
  });

  test('setlist reminder is queued at 10:00 for yesterday until it is confirmed', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    final seeded = await seedConfirmedGig(
      repository,
      clock: () => clock,
      date: DateTime(2026, 10, 11),
      venue: 'USF Verftet, Bergen',
      organizer: 'USF Verftet',
    );
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );

    expect(
      repository.enqueueSetlistReminders(at: DateTime(2026, 10, 12, 9)),
      isEmpty,
    );

    final notices = repository.enqueueSetlistReminders(at: DateTime(2026, 10, 12, 10));
    expect(notices, hasLength(1));
    expect(notices.single.body, setlistPushBody);
    expect(notices.single.url, '/artist/gigs/${seeded.gigId}/settliste');
    expect(notices.single.to, DemoCatalog.artistEmail);
    expect(notices.single.subject, setlistPushTitle);

    await repository.saveSetlist(
      gigId: seeded.gigId,
      tracks: const [SetlistTrack(title: 'Nordavind', duration: '03:45')],
    );
    expect(
      repository.enqueueSetlistReminders(at: DateTime(2026, 10, 12, 10)),
      isEmpty,
    );
  });
}

BookingDraft _draft({int day = 20}) {
  return BookingDraft(
    artistId: DemoCatalog.linnId,
    date: DateTime(2026, 10, day),
    organizerName: 'Oslo Live',
    organization: 'Oslo Live',
    contactPerson: 'Kari',
    email: 'kari@example.com',
    phone: '900 00 000',
    venueCity: 'Parkteatret, Oslo',
    notes: '',
  );
}
