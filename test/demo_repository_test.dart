import 'package:amundsen_booking/core/errors.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/models/booking_draft.dart';
import 'package:amundsen_booking/models/production_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_fixtures.dart';

void main() {
  final clock = DateTime(2026, 10, 11);

  test('inquiry is stored with the chosen date', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    final target = DateTime(2026, 10, 16);
    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    await repository.setAvailability(
      artistId: DemoCatalog.linnId,
      date: target,
      isAvailable: true,
    );
    final days = await repository.fetchAvailability(
      artistId: DemoCatalog.linnId,
      from: target,
      to: target,
    );
    final openDay = days.single.date;
    expect(days.single.isAvailable, isTrue);

    await repository.submitBooking(
      BookingDraft(
        artistId: DemoCatalog.linnId,
        date: openDay,
        organizerName: 'Nordlys Scene',
        organization: 'Nordlys Scene AS',
        contactPerson: 'Ida Solheim',
        email: 'ida@example.com',
        phone: '90011223',
        venueCity: 'USF Verftet, Bergen',
        notes: 'Utendørs',
      ),
    );

    expect(repository.bookings, hasLength(1));
    expect(repository.bookings.single.organizerName, 'Nordlys Scene');
    expect(repository.bookings.single.date, openDay);
  });

  test('a blocked date is rejected', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    final blocked = DateTime(2026, 10, 20);
    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    await repository.setAvailability(
      artistId: DemoCatalog.linnId,
      date: blocked,
      isAvailable: false,
    );

    expect(
      () => repository.submitBooking(
        BookingDraft(
          artistId: DemoCatalog.linnId,
          date: blocked,
          organizerName: 'Nordlys Scene',
          organization: 'Nordlys Scene AS',
          contactPerson: 'Ida Solheim',
          email: 'ida@example.com',
          phone: '90011223',
          venueCity: 'Bergen',
          notes: '',
        ),
      ),
      throwsA(isA<PortalException>()),
    );
  });

  test('production link loads the gig and saves the run of show', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    final missing = await repository.fetchGig('ukjent');
    expect(missing, isNull);

    final seeded = await seedConfirmedGig(
      repository,
      clock: () => clock,
      date: DateTime(2026, 11, 1),
      venue: 'Koengen, Bergen',
      organizer: 'Bergensfestivalen AS',
    );
    final gig = await repository.fetchGig(seeded.bookingToken);
    expect(gig, isNotNull);
    expect(gig!.artistName, 'Rolffa');
    expect(gig.organizer.venueCity, 'Koengen, Bergen');
    expect(gig.organizer.organization, 'Bergensfestivalen AS');
    expect(gig.status, 'confirmed');
    expect(gig.date, DateTime(2026, 11, 1));

    final held = await repository.fetchAvailability(
      artistId: gig.artistId,
      from: gig.date,
      to: gig.date,
    );
    expect(held.single.isAvailable, isFalse);
    expect(
      () => repository.submitBooking(
        BookingDraft(
          artistId: gig.artistId,
          date: gig.date,
          organizerName: 'Annen scene',
          organization: 'Annen scene AS',
          contactPerson: 'Per',
          email: 'per@example.com',
          phone: '90000000',
          venueCity: 'Oslo',
          notes: '',
        ),
      ),
      throwsA(isA<PortalException>()),
    );
    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    expect(
      () => repository.setAvailability(
        artistId: gig.artistId,
        date: gig.date,
        isAvailable: true,
      ),
      throwsA(isA<PortalException>()),
    );

    final saved = await repository.saveProduction(
      bookingToken: seeded.bookingToken,
      plan: const ProductionPlan(
        eventName: 'Koengen',
        accommodationName: 'Hotel Norge',
        getIn: TimeOfDay(hour: 14, minute: 0),
        soundcheck: TimeOfDay(hour: 16, minute: 0),
        showGetIn: TimeOfDay(hour: 18, minute: 30),
        showStart: TimeOfDay(hour: 21, minute: 0),
        curfew: TimeOfDay(hour: 23, minute: 0),
      ),
    );

    expect(saved.status, 'ready');
    expect(saved.production.eventName, 'Koengen');
    expect(saved.production.showStart, const TimeOfDay(hour: 21, minute: 0));
  });

  test('admin login toggles a date for the public calendar', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    expect(
      () => repository.signInAdmin(username: 'admin', password: 'feil'),
      throwsA(isA<PortalException>()),
    );
    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );

    final day = DateTime(2026, 10, 12);
    await repository.setAvailability(
      artistId: DemoCatalog.fjordId,
      date: day,
      isAvailable: true,
    );
    final days = await repository.fetchAvailability(
      artistId: DemoCatalog.fjordId,
      from: day,
      to: day,
    );
    expect(days.single.isAvailable, isTrue);

    await repository.setAvailability(
      artistId: DemoCatalog.fjordId,
      date: day,
      isAvailable: !days.single.isAvailable,
    );

    final updated = await repository.fetchAvailability(
      artistId: DemoCatalog.fjordId,
      from: day,
      to: day,
    );
    expect(updated.single.isAvailable, isNot(days.single.isAvailable));

    repository.signOutAdmin();
    expect(
      () => repository.setAvailability(
        artistId: DemoCatalog.fjordId,
        date: day,
        isAvailable: true,
      ),
      throwsA(isA<PortalException>()),
    );
  });
}
