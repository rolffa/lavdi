import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/artist.dart';
import '../models/artist_offer.dart';
import '../models/artist_session.dart';
import '../models/band.dart';
import '../models/availability_day.dart';
import '../models/booking_deal.dart';
import '../models/booking_draft.dart';
import '../models/booking_request.dart';
import '../models/gig.dart';
import '../models/press_kit.dart';
import '../models/production_plan.dart';
import '../models/push_notice.dart';
import '../models/repertoire.dart';
import '../models/stage_plot.dart';
import '../models/venue_note.dart';

abstract class PortalRepository {
  /// Public catalog. Only published artists.
  Future<List<Artist>> fetchArtists();

  /// Public artist page. Null when missing or unpublished.
  Future<Artist?> fetchArtist(String id);

  /// All artists for admin tools, including unpublished.
  Future<List<Artist>> fetchAdminArtists();

  Future<void> setArtistPublished({
    required String artistId,
    required bool published,
  });

  Future<List<AvailabilityDay>> fetchAvailability({
    required String artistId,
    required DateTime from,
    required DateTime to,
  });

  /// Marks or clears dates on the logged-in band's availability calendar.
  /// Confirmed gigs are left unchanged.
  Future<void> saveMyAvailability({
    required List<DateTime> dates,
    required bool available,
  });

  Future<void> submitBooking(BookingDraft draft);

  Future<Gig?> fetchGig(String bookingToken);

  Future<Gig> saveProduction({
    required String bookingToken,
    required ProductionPlan plan,
  });

  bool get isAdminSignedIn;

  Future<void> signInAdmin({required String username, required String password});

  void signOutAdmin();

  Future<void> setAvailability({
    required String artistId,
    required DateTime date,
    required bool isAvailable,
  });

  Future<ArtistSession?> currentArtist();

  Future<ArtistSession> signInArtist({required String email, required String password});

  /// True when the session is ready immediately. False when an email was sent.
  Future<bool> sendArtistLink(String email);

  Future<void> signOutArtist();

  Future<List<Gig>> fetchMyGigs();

  Future<List<RepertoireTrack>> fetchRepertoire();

  Future<RepertoireTrack> saveRepertoireTrack({
    String? id,
    required String title,
    required String duration,
  });

  Future<void> deleteRepertoireTrack(String id);

  Future<ConcertSetlist> fetchSetlist(String gigId);

  Future<ConcertSetlist> saveSetlist({
    required String gigId,
    required List<SetlistTrack> tracks,
  });

  Future<BandOverview?> fetchMyBand();

  Future<BandOverview> createBand({required String name, required String contact});

  Future<Band> updateBand({
    required String name,
    required String contact,
    required String sharedTech,
    required String sharedHospitality,
  });

  Future<Band> saveTechnicalRider({
    required String inputList,
    required String monitors,
    required String stageRig,
    required String paRequirements,
  });

  Future<StagePlot?> fetchStagePlot();

  Future<StagePlot> uploadStagePlot({required String filename, required Uint8List bytes});

  Future<void> clearStagePlot();

  Future<BandMember> saveMyProfile({
    required String name,
    required String role,
    required String phone,
    required String food,
    required String personalTech,
  });

  Future<BandInvite> inviteMember({required String email, required String role});

  /// Sends the magic link to the invited address. Called from the invite page,
  /// so the login verifier stays on the member's own browser.
  Future<void> sendInviteEmail(String token);

  Future<void> revokeInvite(String inviteId);

  Future<BandInvitePreview?> previewInvite(String token);

  Future<BandMember> acceptInvite(String token);

  Future<BandRoster?> fetchRiders(String bookingToken);

  /// Bookingansvarlig sender et tilbud som artisten må godkjenne.
  Future<void> sendOffer({
    required String artistId,
    required DateTime date,
    required int fee,
    required String venue,
    required String organizerName,
    required String message,
  });

  Future<List<ArtistOffer>> fetchMyOffers();

  Future<void> respondToOffer({
    required String offerId,
    required bool approve,
    String comment = '',
  });

  Future<void> undoOfferDecline(String offerId);

  Future<List<ArtistOffer>> fetchDeclinedOffers();

  /// Forespørsel fra arrangør. Bare bandleder eller admin i bandet får den.
  Future<BookingRequest?> fetchBookingRequest(String id);

  Stream<PushNotice> get pushNotices;

  Future<String> pushPublicKey();

  Future<bool> hasPushSubscription();

  Future<void> savePushSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
  });

  Future<void> removePushSubscription(String endpoint);

  Future<PressKit?> fetchMyPressKit();

  Future<PressKit> savePressBio(String bio);

  Future<PressKit> savePressPhoto({
    required int slot,
    required String filename,
    required Uint8List bytes,
  });

  Future<Uint8List> downloadPressPhoto(PressPhoto photo);

  Future<PressKit?> fetchPublicPressKit(String slug);

  Future<List<VenueNote>> fetchVenueNotes();

  Future<VenueNote> addVenueNote({
    required String venueName,
    required String city,
    required String loadInNotes,
    required String soundLightingNotes,
    required String hospitalityNotes,
    required String contactNotes,
  });

  Future<List<BookingDeal>> fetchDeals();

  Future<List<BookingDeal>> fetchArchivedDeals();

  Future<void> archiveDeal(String dealId);

  Future<void> unarchiveDeal(String dealId);

  Future<void> sendDealToArtist({
    required String dealId,
    required int fee,
    required String message,
  });

  Future<void> signDeal(String dealId);

  Future<void> confirmDeal(String dealId);

  Future<BookingDeal?> fetchDealByTravelToken(String token);

  Future<void> saveOrganizerTravel({
    required String token,
    required String airport,
    required String distance,
    String route = '',
  });

  Future<BookingDeal?> fetchDealByDayToken(String token);

  Future<void> saveOrganizerDay({
    required String token,
    required TimeOfDay getIn,
    required TimeOfDay soundcheck,
    required TimeOfDay showStart,
    required String dinnerPlace,
    required String hotelName,
    required String hotelAddress,
    required String notes,
  });

  Future<List<CrewLeg>> fetchCrewTravel(String gigId);

  Future<List<CrewLeg>> saveCrewTravel({
    required String gigId,
    required String memberId,
    required DateTime arrival,
    required DateTime departure,
    required String pickup,
    required String dropoff,
  });

  Future<List<CrewLeg>> setCrewMemberActive({
    required String gigId,
    required String memberId,
    required bool active,
  });
}
