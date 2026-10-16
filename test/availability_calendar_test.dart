import 'package:amundsen_booking/core/calendar_logic.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/models/booking_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final clock = DateTime(2026, 10, 12);

  test('weekends in the visible month start on friday and saturday', () {
    final days = weekendDaysInMonth(DateTime(2026, 10), notBefore: clock);
    expect(days, contains(DateTime(2026, 10, 16)));
    expect(days, contains(DateTime(2026, 10, 17)));
    expect(days, isNot(contains(DateTime(2026, 10, 10))));
    expect(days, isNot(contains(DateTime(2026, 10, 11))));
    expect(days.every((day) => day.weekday == DateTime.friday || day.weekday == DateTime.saturday), isTrue);
  });

  test('artist marks flow to the public calendar and booked days stay locked', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    final before = await repository.fetchAvailability(
      artistId: DemoCatalog.linnId,
      from: DateTime(2026, 10, 16),
      to: DateTime(2026, 10, 16),
    );
    expect(before, isEmpty);

    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.saveMyAvailability(
      dates: [DateTime(2026, 10, 16)],
      available: true,
    );

    final open = await repository.fetchAvailability(
      artistId: DemoCatalog.linnId,
      from: DateTime(2026, 10, 16),
      to: DateTime(2026, 10, 16),
    );
    expect(open.single.isAvailable, isTrue);
    expect(open.single.isBooked, isFalse);

    final gigDay = DateTime(2026, 11, 2);
    await repository.saveMyAvailability(dates: [gigDay], available: true);
    final held = await repository.fetchAvailability(
      artistId: DemoCatalog.linnId,
      from: gigDay,
      to: gigDay,
    );
    expect(held.single.isAvailable, isFalse);
    expect(held.single.isBooked, isTrue);

    await repository.saveMyAvailability(
      dates: [DateTime(2026, 10, 16)],
      available: false,
    );
    final closed = await repository.fetchAvailability(
      artistId: DemoCatalog.linnId,
      from: DateTime(2026, 10, 16),
      to: DateTime(2026, 10, 16),
    );
    expect(closed, isEmpty);
  });

  test('confirming a deal marks the date booked in the calendar', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    final day = DateTime(2026, 11, 20);
    await repository.saveMyAvailability(dates: [day], available: true);
    await repository.submitBooking(
      BookingDraft(
        artistId: DemoCatalog.linnId,
        date: day,
        organizerName: 'Scenehuset',
        organization: 'Scenehuset AS',
        contactPerson: 'Kari',
        email: 'kari@scene.no',
        phone: '90000000',
        venueCity: 'Oslo',
        notes: '',
      ),
    );
    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    final inquiry = (await repository.fetchDeals()).lastWhere(
      (deal) => isSameDay(deal.date, day),
    );
    await repository.sendDealToArtist(
      dealId: inquiry.id,
      fee: 80000,
      message: 'Ok',
    );
    final offer = (await repository.fetchMyOffers()).singleWhere(
      (item) => isSameDay(item.date, day),
    );
    await repository.respondToOffer(offerId: offer.id, approve: true);
    await repository.confirmDeal(inquiry.id);

    final after = await repository.fetchAvailability(
      artistId: DemoCatalog.linnId,
      from: day,
      to: day,
    );
    expect(after.single.isBooked, isTrue);
    expect(after.single.isAvailable, isFalse);
  });
}
