import 'package:amundsen_booking/core/deal_logic.dart';
import 'package:amundsen_booking/core/errors.dart';
import 'package:amundsen_booking/core/push_logic.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/models/booking_deal.dart';
import 'package:amundsen_booking/models/booking_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final clock = DateTime(2026, 10, 12, 12);

  test('reply window is 48 hours and the day sheet is due a month before', () {
    final deadline = offerReplyDeadline(clock);
    expect(deadline, DateTime(2026, 10, 14, 12));
    expect(replyWindowLabel(deadline, clock), '48 t 0 min igjen av 48 timer');
    expect(replyWindowLabel(clock, deadline), 'Svarfristen er ute');
    expect(daySheetDue(DateTime(2026, 11, 20)), DateTime(2026, 10, 21));
    expect(
      crewTravelComplete(const [
        CrewLeg(memberId: 'a', name: 'A', role: 'Lyd', active: false),
        CrewLeg(memberId: 'b', name: 'B', role: 'Vokal', booked: true),
      ]),
      isTrue,
    );
  });

  test('admin sends an inquiry to the artist, then confirms after both signatures', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.saveMyAvailability(dates: [DateTime(2026, 11, 20)], available: true);
    await repository.submitBooking(
      BookingDraft(
        artistId: DemoCatalog.linnId,
        date: DateTime(2026, 11, 20),
        organizerName: 'Kulturhuset',
        organization: 'Kulturhuset',
        contactPerson: 'Eva',
        email: 'eva@example.com',
        phone: '900 40 040',
        venueCity: 'Kulturhuset, Tromsø',
        notes: 'Lørdag.',
      ),
    );

    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );
    final before = await repository.fetchDeals();
    final inquiry = before.singleWhere((deal) => deal.venue.contains('Tromsø'));
    expect(before.any((deal) => deal.id == 'booking-demo-inquiry' && deal.inquiry), isTrue);
    final offersBefore = await repository.fetchMyOffers();
    expect(offersBefore.every((offer) => offer.venue != inquiry.venue), isTrue);

    await repository.sendDealToArtist(
      dealId: inquiry.id,
      fee: 70000,
      message: 'Pris avtalt.',
    );
    final offer = (await repository.fetchMyOffers()).singleWhere(
      (item) => item.venue.contains('Tromsø'),
    );
    expect(offer.fee, 70000);
    expect(offer.deadline, offerReplyDeadline(clock));

    await repository.respondToOffer(offerId: offer.id, approve: true);
    await repository.confirmDeal(inquiry.id);

    final confirmed = (await repository.fetchDeals()).singleWhere(
      (deal) => deal.id == inquiry.id,
    );
    expect(confirmed.confirmed, isTrue);
    expect(confirmed.pressReady, isTrue);
    expect(confirmed.travelToken, isNotEmpty);
    expect(confirmed.crew, hasLength(2));

    final gigBeforeTravel = (await repository.fetchMyGigs()).singleWhere(
      (item) => item.organizer.venueCity.contains('Tromsø'),
    );
    expect(gigBeforeTravel.production.travelBriefReady, isFalse);
    expect(repository.mailOutbox.where((mail) => mail.subject == travelBookPushTitle), isEmpty);

    final crewBefore = await repository.fetchCrewTravel(gigBeforeTravel.id);
    expect(
      () => repository.saveCrewTravel(
        gigId: gigBeforeTravel.id,
        memberId: crewBefore.first.memberId,
        arrival: DateTime(2026, 11, 20, 12),
        departure: DateTime(2026, 11, 21, 10),
        pickup: 'Tromsø lufthavn',
        dropoff: 'Tromsø lufthavn',
      ),
      throwsA(isA<PortalException>()),
    );

    await repository.saveOrganizerTravel(
      token: confirmed.travelToken,
      airport: 'Tromsø lufthavn',
      distance: '12 km / 20 minutter',
      route: 'Taxi fra flyplassen rett til hotellet.',
    );
    expect(
      repository.mailOutbox.where((mail) => mail.subject == travelBookPushTitle),
      isNotEmpty,
    );

    await repository.saveOrganizerDay(
      token: confirmed.dayToken,
      getIn: const TimeOfDay(hour: 14, minute: 0),
      soundcheck: const TimeOfDay(hour: 16, minute: 0),
      showStart: const TimeOfDay(hour: 21, minute: 0),
      dinnerPlace: 'Mathallen',
      hotelName: 'Clarion',
      hotelAddress: 'Storgata 1, Tromsø',
      notes: 'Last inn fra bakgården.',
    );

    final gig = (await repository.fetchMyGigs()).singleWhere(
      (item) => item.organizer.venueCity.contains('Tromsø'),
    );
    expect(gig.production.nearestAirport, 'Tromsø lufthavn');
    expect(gig.production.airportDistance, '12 km / 20 minutter');
    expect(gig.production.travelRoute, 'Taxi fra flyplassen rett til hotellet.');
    expect(gig.production.travelBriefReady, isTrue);
    expect(gig.production.daySheetReady, isTrue);
    expect(gig.production.accommodationAddress, 'Storgata 1, Tromsø');

    final crew = await repository.fetchCrewTravel(gig.id);
    await repository.setCrewMemberActive(gigId: gig.id, memberId: crew.last.memberId, active: false);
    await repository.saveCrewTravel(
      gigId: gig.id,
      memberId: crew.first.memberId,
      arrival: DateTime(2026, 11, 20, 12),
      departure: DateTime(2026, 11, 21, 10),
      pickup: 'Tromsø lufthavn',
      dropoff: 'Tromsø lufthavn',
    );
    final done = (await repository.fetchDeals()).singleWhere(
      (deal) => deal.id == inquiry.id,
    );
    expect(crewTravelComplete(done.crew), isTrue);
  });
}
