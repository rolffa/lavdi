import 'package:amundsen_booking/core/calendar_logic.dart';
import 'package:amundsen_booking/core/format.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/models/booking_draft.dart';
import 'package:amundsen_booking/models/booking_deal.dart';
import 'package:amundsen_booking/models/gig.dart';
import 'package:amundsen_booking/models/production_plan.dart';

/// Creates a pending artist offer (withArtist) for Rolffa on [date].
Future<BookingDeal> seedPendingOffer(
  DemoPortalRepository repository, {
  DateTime? date,
  int fee = 90000,
  String venue = 'Parkteatret, Oslo',
  String organizer = 'Oslo Live',
  String message = 'Tilbud om kveldskonsert.',
}) async {
  final day = date ?? DateTime(2026, 10, 24);
  await repository.signInArtist(
    email: DemoCatalog.artistEmail,
    password: DemoCatalog.artistPassword,
  );
  await repository.saveMyAvailability(dates: [day], available: true);
  await repository.submitBooking(
    BookingDraft(
      artistId: DemoCatalog.linnId,
      date: day,
      organizerName: organizer,
      organization: organizer,
      contactPerson: 'Kari',
      email: 'kari@example.com',
      phone: '900 00 000',
      venueCity: venue,
      notes: '',
    ),
  );
  await repository.signInAdmin(
    username: DemoCatalog.adminUsername,
    password: DemoCatalog.adminPassword,
  );
  final inquiry = (await repository.fetchDeals()).lastWhere(
    (deal) =>
        deal.artistId == DemoCatalog.linnId &&
        deal.venue == venue &&
        deal.inquiry,
  );
  await repository.sendDealToArtist(
    dealId: inquiry.id,
    fee: fee,
    message: message,
  );
  return (await repository.fetchDeals()).singleWhere((deal) => deal.id == inquiry.id);
}

/// Creates a confirmed gig and returns it.
///
/// Past dates are injected directly (booking flow rejects past days).
Future<({String bookingToken, String gigId})> seedConfirmedGig(
  DemoPortalRepository repository, {
  required DateTime Function() clock,
  DateTime? date,
  String venue = 'Koengen, Bergen',
  String organizer = 'Bergensfestivalen',
}) async {
  final day = dateOnly(date ?? DateTime(2026, 11, 1));
  if (isPastDay(day, clock())) {
    final gigId = 'gig-past-${day.millisecondsSinceEpoch}';
    final token = 'produksjon-$gigId';
    repository.debugAddConfirmedGig(
      Gig(
        id: gigId,
        bookingId: 'booking-$gigId',
        bookingToken: token,
        artistId: DemoCatalog.linnId,
        artistName: 'Rolffa',
        date: day,
        status: 'ready',
        organizer: Organizer(
          name: organizer,
          organization: organizer,
          contactPerson: 'Kari',
          email: 'kari@example.com',
          phone: '900 00 000',
          venueCity: venue,
        ),
        production: const ProductionPlan(),
      ),
    );
    return (bookingToken: token, gigId: gigId);
  }

  final deal = await seedPendingOffer(
    repository,
    date: day,
    venue: venue,
    organizer: organizer,
    fee: 85000,
    message: 'Bekreftet.',
  );
  await repository.signInArtist(
    email: DemoCatalog.artistEmail,
    password: DemoCatalog.artistPassword,
  );
  await repository.respondToOffer(offerId: deal.id, approve: true);
  await repository.signInAdmin(
    username: DemoCatalog.adminUsername,
    password: DemoCatalog.adminPassword,
  );
  await repository.confirmDeal(deal.id);
  final confirmed =
      (await repository.fetchDeals()).singleWhere((item) => item.id == deal.id);
  await repository.signInArtist(
    email: DemoCatalog.artistEmail,
    password: DemoCatalog.artistPassword,
  );
  final gig = (await repository.fetchMyGigs()).singleWhere(
    (item) => item.id == confirmed.gigId,
  );
  return (bookingToken: gig.bookingToken, gigId: gig.id);
}
