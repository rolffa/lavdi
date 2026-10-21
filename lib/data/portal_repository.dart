import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/admin_notification.dart';
import '../models/artist.dart';
import '../models/artist_offer.dart';
import '../models/artist_session.dart';
import '../models/band.dart';
import '../models/availability_day.dart';
import '../models/booking_deal.dart';
import '../models/booking_draft.dart';
import '../models/booking_request.dart';
import '../models/gig.dart';
import '../models/member_conflict.dart';
import '../models/musician_band.dart';
import '../models/press_kit.dart';
import '../models/production_plan.dart';
import '../models/push_notice.dart';
import '../models/repertoire.dart';
import '../models/stage_plot.dart';
import '../models/venue_note.dart';

abstract class PortalRepository extends ChangeNotifier {
  /// Public catalog. Only published artists.
  Future<List<Artist>> fetchArtists();

  /// Public artist page. Null when missing or unpublished.
  Future<Artist?> fetchArtist(String id);

  /// All artists for admin tools, including unpublished.
  Future<List<Artist>> fetchAdminArtists();

  /// Oppdateringer under Artister (invitasjon / aktivering).
  Future<List<AdminNotification>> fetchAdminNotifications();

  Future<void> dismissAdminNotification(String id);

  Future<void> setArtistPublished({
    required String artistId,
    required bool published,
  });

  /// Admin is browsing an artist portal without a band login.
  bool get isAdminViewingAsArtist => adminViewAsArtist != null;

  /// Active «se som artist»-session, or null.
  ArtistSession? get adminViewAsArtist;

  /// Rydd «se som artist» før vanlig Artist-innlogging (f.eks. fra forsiden).
  Future<void> preparePublicArtistEntry();

  /// Opens the given artist's portal for the signed-in admin.
  Future<ArtistSession> openArtistPortalAsAdmin(String artistId);

  /// Leaves admin artist-view and restores normal admin session.
  Future<void> closeArtistPortalAsAdmin();

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

  /// Current admin username after sign-in, or empty.
  String get adminUsername;

  /// Auth e-post for adminkontoen (Supabase Auth). Tom før innlogging i live-modus.
  String get adminAuthEmail;

  Future<void> changeAdminPassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<String?> fetchAdminAvatarUrl();

  Future<String> uploadAdminAvatar({
    required String filename,
    required Uint8List bytes,
  });

  Future<void> changeArtistPassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Sets a password for the signed-in artist (invite / first-time setup).
  Future<void> setArtistPassword(String password);

  Future<String?> fetchMyAvatarUrl();

  Future<String> uploadMyAvatar({
    required String filename,
    required Uint8List bytes,
  });

  Future<List<BandMember>> fetchAdminBandAccounts(String artistId);

  Future<BandInvite> adminInviteBandMember({
    required String artistId,
    required String email,
    required String role,
    bool asLeader = false,
  });

  Future<void> adminRemoveBandMember({
    required String artistId,
    required String memberId,
  });

  /// Sends a one-time login / reset link to the given email.
  Future<void> adminSendPasswordReset(String email);

  /// Public «glemt passord» — sender nullstillingslenke uten admin.
  Future<void> requestPasswordReset(String email);

  /// True after opening a recovery link until the user sets a new password.
  bool get passwordRecoveryPending;

  void clearPasswordRecoveryPending();

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

  /// E-postadresser som mottar tilbud og settlistepåminnelser for artisten.
  Future<List<String>> fetchBandNotifyEmails(String artistId);

  /// All bands the signed-in musician belongs to (for switcher / combined calendar).
  Future<List<MusicianBand>> fetchMyBands();

  /// Sets which band the portal works in (profile, riders, single-band calendar edits).
  Future<void> setActiveBand(String bandId);

  /// Available and booked days across every membership, stamped with band name.
  Future<List<CombinedCalendarMark>> fetchCombinedCalendar({
    required DateTime from,
    required DateTime to,
  });

  /// Ensures the signed-in (or admin-viewed) artist has a band, then returns it.
  Future<BandOverview> ensureMyBand();

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

  /// Creates invite and e-mails the activation link to the address.
  Future<BandInvite> inviteMember({required String email, required String role});

  /// Removes a band member (inkl. bandleder).
  Future<void> removeMember(String memberId);

  /// Sends (or resends) the activation e-mail to the invited address.
  Future<void> sendInviteEmail(String token);

  Future<void> revokeInvite(String inviteId);

  Future<BandInvitePreview?> previewInvite(String token);

  Future<BandMember> acceptInvite(String token);

  /// Auth-e-post etter magic link / bekreftelse (kan finnes før artist er koblet).
  String? currentAuthEmail();

  /// Vent kort på at redirect-lenken etablerer Auth-sesjon.
  Future<String?> waitForAuthEmail({
    Duration timeout = const Duration(seconds: 8),
  });

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

  /// Members of [artistId]'s band who are booked with another band on [date].
  Future<List<MemberDateConflict>> fetchMemberConflicts({
    required String artistId,
    required DateTime date,
  });

  /// Upcoming dates where the active band's members are booked elsewhere.
  Future<List<MemberDateConflict>> fetchMyBandBusyNotices();

  Future<void> respondToOffer({
    required String offerId,
    required bool approve,
    String comment = '',
  });

  /// Generates (or regenerates) the concert contract PDF for a gig and returns bytes.
  Future<Uint8List> downloadContractPdfForGig(String gigId);

  Future<void> undoOfferDecline(String offerId);

  Future<List<ArtistOffer>> fetchDeclinedOffers();

  /// Forespørsel fra arrangør til bandet.
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
