import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/artist_slug.dart';
import '../core/calendar_logic.dart';
import '../core/deal_logic.dart';
import '../core/errors.dart';
import '../core/format.dart';
import '../core/push_config.dart';
import '../core/push_logic.dart';
import '../core/tono.dart';
import '../models/artist.dart';
import '../models/artist_offer.dart';
import '../models/artist_session.dart';
import '../models/band.dart';
import '../models/repertoire.dart';
import '../models/availability_day.dart';
import '../models/booking_deal.dart';
import '../models/booking_draft.dart';
import '../models/booking_request.dart';
import '../models/gig.dart';
import '../models/press_kit.dart';
import '../models/leader_mail.dart';
import '../models/push_notice.dart';
import '../models/production_plan.dart';
import '../models/stage_plot.dart';
import '../models/venue_note.dart';
import 'demo_catalog.dart';
import 'portal_repository.dart';

class DemoPortalRepository implements PortalRepository {
  DemoPortalRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final List<BookingDraft> bookings = [];
  final Map<String, bool> _overrides = {};
  final Map<String, bool> _published = {
    for (final artist in DemoCatalog.artists) artist.id: true,
  };
  late final List<Gig> _gigs = _seedGigs();
  final List<BookingDeal> _deals = [];
  var _dealReady = false;
  ArtistSession? _session;
  String? _adminSecret;
  final List<RepertoireTrack> _repertoire = [
    const RepertoireTrack(id: 'rep-1', title: 'Nordavind', duration: '03:45'),
    const RepertoireTrack(id: 'rep-2', title: 'Etter midnatt', duration: '04:12'),
    const RepertoireTrack(id: 'rep-3', title: 'Koengens lys', duration: '03:20'),
  ];
  final Map<String, ConcertSetlist> _setlists = {};
  var _trackSequence = 4;
  var _memberSequence = 3;
  Band? _band = const Band(
    id: 'band-rolffa',
    artistId: DemoCatalog.linnId,
    name: 'Rolffa',
    contact: 'rolffa@lavdi.no · 900 10 010',
    sharedTech: '2 vokal, gitar og keys. Stereomix til IEM. 4 linjer DI.',
    sharedHospitality:
        'Stille backstage med vann, kaffe og et rom til omkledning. 2 enkeltrom.',
    inputList: 'Vokal 1, vokal 2, gitar og keys. 4 linjer DI.',
    monitors: 'Stereomix til IEM for begge. Ingen wedges.',
    stageRig: 'Ingen DJ. Keys og gitar på scenen.',
    paRequirements: 'Stereo PA med headroom til vokal.',
  );
  final List<BandMember> _members = [
    const BandMember(
      id: 'member-rolffa',
      bandId: 'band-rolffa',
      userId: 'user-rolffa',
      name: 'Rolffa',
      role: 'Bandleder',
      phone: '900 10 010',
      food: 'Vegetar. Ingen nøtter.',
      personalTech: 'IEM, Shure PSM 300. Egen pack.',
      email: DemoCatalog.artistEmail,
      isLeader: true,
    ),
    const BandMember(
      id: 'member-sigrid',
      bandId: 'band-rolffa',
      userId: 'user-sigrid',
      name: 'Sigrid Holm',
      role: 'Musiker',
      phone: '900 20 020',
      food: 'Glutenfri.',
      personalTech: 'Trådløs gitar, egen sender.',
      email: 'sigrid@lavdi.no',
    ),
  ];
  final List<BandInvite> _invites = [
    const BandInvite(
      id: 'invite-lyd',
      bandId: 'band-rolffa',
      email: 'lyd@lavdi.no',
      role: 'Lydtekniker',
      token: 'demo-lyd',
    ),
  ];
  StagePlot? _stagePlot;
  final Map<String, List<CrewLeg>> _crewByGig = {};
  final Map<String, ({String endpoint, String p256dh, String auth})> _pushByUser = {};
  final List<PushNotice> _pushOutbox = [];
  final List<LeaderMail> _mailOutbox = [];
  final StreamController<PushNotice> _pushNotices = StreamController<PushNotice>.broadcast();
  var _inquirySequence = 0;
  var _venueNoteSequence = 1;
  late PressKit _pressKit = _seedPressKit();
  final List<VenueNote> _venueNotes = [
    VenueNote(
      id: 'note-koengen',
      bandId: 'band-rolffa',
      venueName: 'Koengen',
      city: 'Bergen',
      loadInNotes: 'Bæring fra baksiden. Heis til scenenivå.',
      soundLightingNotes: 'God PA. Teknisk ansvarlig kjenner IEM.',
      hospitalityNotes: 'Garderobe under scenen. Varm mat i backstage.',
      contactNotes: 'Ida møter i døren.',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    ),
  ];

  List<Gig> _seedGigs() {
    final upcoming = addCalendarDays(_clock(), 21);
    final yesterday = addCalendarDays(_clock(), -1);
    return [
      Gig(
        id: 'b2000000-0000-4000-8000-000000000002',
        bookingId: 'c3000000-0000-4000-8000-000000000002',
        bookingToken: 'amundsen-demo-rolffa-igår',
        artistId: DemoCatalog.linnId,
        artistName: 'Rolffa',
        date: yesterday,
        status: 'ready',
        organizer: const Organizer(
          name: 'USF Verftet',
          organization: 'USF Verftet',
          contactPerson: 'Ida Solheim',
          email: 'ida@example.com',
          phone: '900 22 110',
          venueCity: 'USF Verftet, Bergen',
        ),
        production: const ProductionPlan(
          eventName: 'Kvelden på USF',
          accommodationName: 'Hotel Norge',
          accommodationAddress: 'Nedre Ole Bulls plass 4, Bergen',
          nearestAirport: 'Bergen lufthavn, Flesland',
          airportDistance: '20 minutter med taxi',
          travelRoute: 'Fly til BGO, taxi 20 minutter til hotellet.',
          getIn: TimeOfDay(hour: 15, minute: 0),
          soundcheck: TimeOfDay(hour: 16, minute: 30),
          showGetIn: TimeOfDay(hour: 18, minute: 0),
          dinner: TimeOfDay(hour: 17, minute: 30),
          showStart: TimeOfDay(hour: 21, minute: 0),
          loadOut: TimeOfDay(hour: 23, minute: 30),
          curfew: TimeOfDay(hour: 23, minute: 0),
          dinnerAtAccommodation: false,
          dinnerVenueName: 'Colonialen',
          dinnerAddress: 'Kong Oscars gate 44, Bergen',
          technicianName: 'Mats Hauge',
          technicianPhone: '900 33 441',
          daySheetReady: true,
        ),
      ),
      Gig(
        id: 'b2000000-0000-4000-8000-000000000001',
        bookingId: DemoCatalog.productionBookingId,
        bookingToken: DemoCatalog.productionToken,
        artistId: DemoCatalog.linnId,
        artistName: 'Rolffa',
        date: upcoming,
        status: 'confirmed',
        organizer: const Organizer(
          name: 'Bergensfestivalen',
          organization: 'Bergensfestivalen AS',
          contactPerson: 'Nora Berg',
          email: 'nora@example.com',
          phone: '900 11 223',
          venueCity: 'Koengen, Bergen',
        ),
        production: const ProductionPlan(
          eventName: 'Koengen',
          accommodationName: 'Hotel Norge',
          accommodationAddress: 'Nedre Ole Bulls plass 4, Bergen',
          nearestAirport: 'Bergen lufthavn, Flesland',
          airportDistance: '20 minutter med taxi',
          travelRoute: 'Fly til BGO, taxi 20 minutter til hotellet.',
          getIn: TimeOfDay(hour: 14, minute: 0),
          soundcheck: TimeOfDay(hour: 16, minute: 0),
          showGetIn: TimeOfDay(hour: 18, minute: 30),
          dinner: TimeOfDay(hour: 17, minute: 0),
          showStart: TimeOfDay(hour: 21, minute: 0),
          loadOut: TimeOfDay(hour: 23, minute: 30),
          curfew: TimeOfDay(hour: 23, minute: 0),
          technicianName: 'Mats Hauge',
          technicianPhone: '900 33 441',
          daySheetReady: true,
        ),
      ),
    ];
  }

  bool _isConfirmed(String artistId, DateTime date) {
    return _gigs.any((gig) => gig.artistId == artistId && isSameDay(gig.date, date));
  }

  bool _isOpen(Artist artist, DateTime day) {
    if (_isConfirmed(artist.id, day)) return false;
    return _overrides[_overrideKey(artist.id, day)] == true;
  }

  Artist? _artist(String id) {
    for (final artist in DemoCatalog.artists) {
      if (artist.id == id) {
        return artist.copyWith(published: _published[artist.id] ?? true);
      }
    }
    return null;
  }

  @override
  Future<List<Artist>> fetchArtists() async {
    return [
      for (final artist in DemoCatalog.artists)
        if (_published[artist.id] ?? true) artist.copyWith(published: true),
    ];
  }

  @override
  Future<Artist?> fetchArtist(String id) async {
    final artist = _artist(id);
    if (artist == null || !artist.published) return null;
    return artist;
  }

  @override
  Future<List<Artist>> fetchAdminArtists() async {
    _requireAdmin();
    return [
      for (final artist in DemoCatalog.artists)
        artist.copyWith(published: _published[artist.id] ?? true),
    ];
  }

  @override
  Future<void> setArtistPublished({
    required String artistId,
    required bool published,
  }) async {
    _requireAdmin();
    if (!DemoCatalog.artists.any((artist) => artist.id == artistId)) {
      throw PortalException('Fant ikke artisten.');
    }
    _published[artistId] = published;
  }

  @override
  Future<List<AvailabilityDay>> fetchAvailability({
    required String artistId,
    required DateTime from,
    required DateTime to,
  }) async {
    final artist = _artist(artistId);
    if (artist == null) return const [];
    final start = dateOnly(from);
    final end = dateOnly(to);
    final days = <AvailabilityDay>[];
    for (var day = start; !day.isAfter(end); day = addCalendarDays(day, 1)) {
      if (_isConfirmed(artist.id, day)) {
        days.add(
          AvailabilityDay(date: day, isAvailable: false, isBooked: true),
        );
        continue;
      }
      final marked = _overrides[_overrideKey(artist.id, day)];
      if (marked == true) {
        days.add(AvailabilityDay(date: day, isAvailable: true));
      } else if (marked == false) {
        days.add(AvailabilityDay(date: day, isAvailable: false));
      }
    }
    return days;
  }

  @override
  Future<void> submitBooking(BookingDraft draft) async {
    final artist = _artist(draft.artistId);
    if (artist == null) {
      throw PortalException('Fant ikke artisten.');
    }
    final available = _isOpen(artist, draft.date);
    if (!available || isPastDay(draft.date, _clock())) {
      throw PortalException('Datoen er ikke tilgjengelig for booking.');
    }
    bookings.add(draft);
    _inquirySequence += 1;
    _ensureSeedDeals();
    _deals.add(
      BookingDeal(
        id: 'booking-$_inquirySequence',
        artistId: draft.artistId,
        artistName: artist.name,
        date: dateOnly(draft.date),
        organizerName: draft.organizerName.trim(),
        organization: draft.organization.trim(),
        contactPerson: draft.contactPerson.trim(),
        email: draft.email.trim(),
        phone: draft.phone.trim(),
        venue: draft.venueCity.trim(),
        notes: draft.notes.trim(),
      ),
    );
  }

  String _overrideKey(String artistId, DateTime date) {
    return '$artistId|${formatIsoDate(date)}';
  }

  Gig? _gigByToken(String bookingToken) {
    for (final gig in _gigs) {
      if (gig.bookingToken == bookingToken) return gig;
    }
    return null;
  }

  void _replaceGig(Gig gig) {
    final index = _gigs.indexWhere((item) => item.id == gig.id);
    if (index >= 0) _gigs[index] = gig;
  }

  ArtistSession _rolffaSession() {
    return const ArtistSession(
      artistId: DemoCatalog.linnId,
      artistName: 'Rolffa',
      email: DemoCatalog.artistEmail,
    );
  }

  void _requireSession() {
    if (_session == null) {
      throw PortalException('Logg inn på nytt.');
    }
  }

  @override
  Future<Gig?> fetchGig(String bookingToken) async => _gigByToken(bookingToken);

  @override
  Future<Gig> saveProduction({
    required String bookingToken,
    required ProductionPlan plan,
  }) async {
    final gig = _gigByToken(bookingToken);
    if (gig == null) {
      throw PortalException('Fant ingen jobb for denne lenken.');
    }
    final updated = gig.copyWith(status: 'ready', production: plan);
    _replaceGig(updated);
    return updated;
  }

  @override
  bool get isAdminSignedIn => _adminSecret != null;

  @override
  Future<void> signInAdmin({required String username, required String password}) async {
    final name = username.trim().toLowerCase();
    if (name != DemoCatalog.adminUsername || password != DemoCatalog.adminPassword) {
      throw PortalException('Feil brukernavn eller passord');
    }
    _adminSecret = password;
  }

  @override
  void signOutAdmin() {
    _adminSecret = null;
  }

  void _requireAdmin() {
    if (_adminSecret == null) {
      throw PortalException('Logg inn på nytt.');
    }
  }

  @override
  Future<void> setAvailability({
    required String artistId,
    required DateTime date,
    required bool isAvailable,
  }) async {
    _requireAdmin();
    if (_artist(artistId) == null) {
      throw PortalException('Fant ikke artisten.');
    }
    if (isAvailable && _isConfirmed(artistId, date)) {
      throw PortalException('Datoen er opptatt av en bekreftet jobb');
    }
    _overrides[_overrideKey(artistId, date)] = isAvailable;
  }

  @override
  Future<void> saveMyAvailability({
    required List<DateTime> dates,
    required bool available,
  }) async {
    _requireSession();
    final artistId = _session!.artistId;
    if (_band?.artistId != artistId) {
      throw PortalException('Opprett bandet før du åpner kalenderen.');
    }
    for (final date in dates) {
      final day = dateOnly(date);
      if (available && _isConfirmed(artistId, day)) continue;
      final key = _overrideKey(artistId, day);
      if (available) {
        _overrides[key] = true;
      } else {
        _overrides.remove(key);
      }
    }
  }

  @override
  Future<ArtistSession?> currentArtist() async => _session;

  @override
  Future<ArtistSession> signInArtist({
    required String email,
    required String password,
  }) async {
    final knownEmail = email.trim().toLowerCase() == DemoCatalog.artistEmail;
    final knownPassword = password == DemoCatalog.artistPassword;
    if (!knownEmail || !knownPassword) {
      throw PortalException('Feil e-post eller passord');
    }
    _session = _rolffaSession();
    return _session!;
  }

  @override
  Future<bool> sendArtistLink(String email) async {
    if (email.trim().toLowerCase() != DemoCatalog.artistEmail) {
      throw PortalException('Fant ingen artist med denne e-posten.');
    }
    _session = _rolffaSession();
    return true;
  }

  @override
  Future<void> signOutArtist() async {
    _session = null;
  }

  @override
  Future<List<Gig>> fetchMyGigs() async {
    _requireSession();
    final mine = _gigs.where((gig) => gig.artistId == _session!.artistId).toList();
    mine.sort((a, b) => a.date.compareTo(b.date));
    return mine;
  }

  @override
  Future<List<RepertoireTrack>> fetchRepertoire() async {
    _requireSession();
    return List<RepertoireTrack>.of(_repertoire);
  }

  @override
  Future<RepertoireTrack> saveRepertoireTrack({
    String? id,
    required String title,
    required String duration,
  }) async {
    _requireSession();
    final playTime = normalizePlayTime(duration);
    if (title.trim().isEmpty || playTime == null) {
      throw PortalException('Tittel og spilletid på formen 03:45 må fylles ut.');
    }
    final track = RepertoireTrack(
      id: (id == null || id.isEmpty) ? 'rep-${_trackSequence++}' : id,
      title: title.trim(),
      duration: playTime,
    );
    final index = _repertoire.indexWhere((item) => item.id == track.id);
    if (index >= 0) {
      _repertoire[index] = track;
    } else {
      _repertoire.add(track);
    }
    return track;
  }

  @override
  Future<void> deleteRepertoireTrack(String id) async {
    _requireSession();
    _repertoire.removeWhere((track) => track.id == id);
  }

  @override
  Future<ConcertSetlist> fetchSetlist(String gigId) async {
    _requireSession();
    _ownGig(gigId);
    return _setlists[gigId] ?? ConcertSetlist.empty(gigId);
  }

  @override
  Future<ConcertSetlist> saveSetlist({
    required String gigId,
    required List<SetlistTrack> tracks,
  }) async {
    _requireSession();
    _ownGig(gigId);
    if (tracks.isEmpty) {
      throw PortalException('Huk av minst én låt.');
    }
    final setlist = ConcertSetlist(
      gigId: gigId,
      tracks: tracks,
      confirmed: true,
      tonoText: formatTonoSetlist(tracks),
    );
    _setlists[gigId] = setlist;
    return setlist;
  }

  BandMember? _me() {
    final email = _session?.email.toLowerCase();
    if (email == null) return null;
    for (final member in _members) {
      if (member.email.toLowerCase() == email) return member;
    }
    return null;
  }

  BandOverview? _overview() {
    final band = _band;
    final me = _me();
    if (band == null || me == null) return null;
    return BandOverview(
      band: band,
      me: me,
      members: List<BandMember>.of(_members),
      invites: me.isLeader
          ? _invites.where((invite) => !invite.accepted).toList()
          : const [],
    );
  }

  void _replaceMember(BandMember member) {
    final index = _members.indexWhere((item) => item.id == member.id);
    if (index >= 0) _members[index] = member;
  }

  @override
  Future<BandOverview?> fetchMyBand() async => _overview();

  @override
  Future<BandOverview> createBand({required String name, required String contact}) async {
    _requireSession();
    if (_me() != null || _band != null) {
      throw PortalException('Bandet finnes allerede.');
    }
    final band = Band(
      id: 'band-${_memberSequence++}',
      artistId: _session!.artistId,
      name: name.trim(),
      contact: contact.trim(),
      sharedTech: '',
      sharedHospitality: '',
    );
    if (band.name.isEmpty) throw PortalException('Bandet trenger et navn.');
    _band = band;
    _members.add(
      BandMember(
        id: 'member-${_memberSequence++}',
        bandId: band.id,
        userId: 'user-${_session!.email}',
        name: band.name,
        role: 'Bandleder',
        phone: '',
        food: '',
        personalTech: '',
        email: _session!.email,
        isLeader: true,
      ),
    );
    return _overview()!;
  }

  @override
  Future<Band> updateBand({
    required String name,
    required String contact,
    required String sharedTech,
    required String sharedHospitality,
  }) async {
    _requireSession();
    final me = _me();
    final band = _band;
    if (me == null || !me.isLeader || band == null) {
      throw PortalException('Bare bandlederen kan oppdatere bandet.');
    }
    if (name.trim().isEmpty) throw PortalException('Bandet trenger et navn.');
    _band = band.copyWith(
      name: name.trim(),
      contact: contact.trim(),
      sharedTech: sharedTech.trim(),
      sharedHospitality: sharedHospitality.trim(),
    );
    return _band!;
  }

  @override
  Future<Band> saveTechnicalRider({
    required String inputList,
    required String monitors,
    required String stageRig,
    required String paRequirements,
  }) async {
    _requireSession();
    final me = _me();
    final band = _band;
    if (me == null || !me.isLeader || band == null) {
      throw PortalException('Bare bandlederen kan oppdatere den tekniske rideren.');
    }
    _band = band.copyWith(
      inputList: inputList.trim(),
      monitors: monitors.trim(),
      stageRig: stageRig.trim(),
      paRequirements: paRequirements.trim(),
    );
    return _band!;
  }

  @override
  Future<StagePlot?> fetchStagePlot() async {
    final band = _band;
    final plot = _stagePlot;
    if (band == null || plot == null || band.stagePlotPath.isEmpty) return null;
    return plot;
  }

  @override
  Future<StagePlot> uploadStagePlot({
    required String filename,
    required Uint8List bytes,
  }) async {
    _requireSession();
    final me = _me();
    final band = _band;
    if (me == null || !me.isLeader || band == null) {
      throw PortalException('Bare bandlederen kan laste opp scenekart.');
    }
    final checked = checkedStagePlot(filename: filename, bytes: bytes);
    final stored = StagePlot(
      name: checked.name,
      contentType: checked.contentType,
      bytes: checked.bytes,
      path: '${band.id}/stage-plot${checked.fileExtension}',
    );
    _stagePlot = stored;
    _band = band.copyWith(
      stagePlotPath: stored.path,
      stagePlotName: stored.name,
      stagePlotType: stored.contentType,
    );
    return stored;
  }

  @override
  Future<void> clearStagePlot() async {
    _requireSession();
    final me = _me();
    final band = _band;
    if (me == null || !me.isLeader || band == null) {
      throw PortalException('Bare bandlederen kan fjerne scenekartet.');
    }
    _stagePlot = null;
    _band = band.copyWith(stagePlotPath: '', stagePlotName: '', stagePlotType: '');
  }

  @override
  Future<BandMember> saveMyProfile({
    required String name,
    required String role,
    required String phone,
    required String food,
    required String personalTech,
  }) async {
    _requireSession();
    final me = _me();
    if (me == null) throw PortalException('Du er ikke med i et band.');
    if (name.trim().isEmpty ||
        role.trim().isEmpty ||
        phone.trim().isEmpty ||
        food.trim().isEmpty ||
        personalTech.trim().isEmpty) {
      throw PortalException('Navn, rolle, telefon, mat og tekniske behov må fylles ut.');
    }
    final updated = me.copyWith(
      name: name.trim(),
      role: role.trim(),
      phone: phone.trim(),
      food: food.trim(),
      personalTech: personalTech.trim(),
    );
    _replaceMember(updated);
    return updated;
  }

  @override
  Future<BandInvite> inviteMember({required String email, required String role}) async {
    _requireSession();
    final me = _me();
    final band = _band;
    if (me == null || !me.isLeader || band == null) {
      throw PortalException('Bare bandlederen kan invitere.');
    }
    final address = email.trim().toLowerCase();
    final crewRole = role.trim();
    if (!address.contains('@')) throw PortalException('Oppgi en gyldig e-postadresse.');
    if (crewRole.isEmpty) throw PortalException('Oppgi en rolle.');
    final existing = _invites.indexWhere(
      (invite) => !invite.accepted && invite.email.toLowerCase() == address,
    );
    final invite = BandInvite(
      id: existing >= 0 ? _invites[existing].id : 'invite-${_memberSequence++}',
      bandId: band.id,
      email: address,
      role: crewRole,
      token: 'demo-${_memberSequence++}',
    );
    if (existing >= 0) {
      _invites[existing] = invite;
    } else {
      _invites.add(invite);
    }
    return invite;
  }

  @override
  Future<void> sendInviteEmail(String token) async {
    final preview = await previewInvite(token);
    if (preview == null) throw PortalException('Invitasjonen finnes ikke.');
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    _requireSession();
    if (_me()?.isLeader != true) {
      throw PortalException('Bare bandlederen kan trekke en invitasjon.');
    }
    _invites.removeWhere((invite) => invite.id == inviteId && !invite.accepted);
  }

  @override
  Future<BandInvitePreview?> previewInvite(String token) async {
    for (final invite in _invites) {
      if (invite.token != token) continue;
      return BandInvitePreview(
        bandName: _band?.name ?? '',
        email: invite.email,
        role: invite.role,
        used: invite.accepted,
      );
    }
    return null;
  }

  @override
  Future<BandMember> acceptInvite(String token) async {
    final index = _invites.indexWhere((invite) => invite.token == token);
    if (index < 0 || _band == null) {
      throw PortalException('Invitasjonen finnes ikke.');
    }
    final invite = _invites[index];
    BandMember? member;
    for (final item in _members) {
      if (item.email.toLowerCase() == invite.email.toLowerCase()) member = item;
    }
    member ??= BandMember(
      id: 'member-${_memberSequence++}',
      bandId: _band!.id,
      userId: 'user-${invite.email}',
      name: '',
      role: invite.role,
      phone: '',
      food: '',
      personalTech: '',
      email: invite.email,
    );
    if (!_members.any((item) => item.id == member!.id)) _members.add(member);
    _invites[index] = BandInvite(
      id: invite.id,
      bandId: invite.bandId,
      email: invite.email,
      role: invite.role,
      token: invite.token,
      accepted: true,
    );
    _session = ArtistSession(
      artistId: _band!.artistId ?? _session?.artistId ?? '',
      artistName: _band!.name,
      email: invite.email,
    );
    return member;
  }

  @override
  Future<BandRoster?> fetchRiders(String bookingToken) async {
    final gig = _gigByToken(bookingToken);
    final band = _band;
    if (gig == null || band == null || gig.artistId != band.artistId) return null;
    return BandRoster(band: band, members: List<BandMember>.of(_members));
  }

  @override
  Future<void> sendOffer({
    required String artistId,
    required DateTime date,
    required int fee,
    required String venue,
    required String organizerName,
    required String message,
  }) async {
    _requireAdmin();
    final artist = _artist(artistId);
    if (artist == null) throw PortalException('Fant ikke artisten.');
    final day = dateOnly(date);
    if (isPastDay(day, _clock())) throw PortalException('Velg en dato som ikke har passert');
    if (fee < 0) throw PortalException('Honorar må være 0 eller høyere');
    if (venue.trim().isEmpty || organizerName.trim().isEmpty) {
      throw PortalException('Spillested og arrangør må fylles ut');
    }
    _ensureSeedDeals();
    if (_isConfirmed(artistId, day)) {
      throw PortalException('Artisten er allerede booket denne datoen');
    }
    if (_deals.any(
      (deal) =>
          deal.withArtist &&
          deal.replyOpen(_clock()) &&
          deal.artistId == artistId &&
          isSameDay(deal.date, day),
    )) {
      throw PortalException('Det ligger allerede et tilbud på denne datoen');
    }
    _inquirySequence += 1;
    final now = _clock();
    _deals.add(
      BookingDeal(
        id: 'booking-$_inquirySequence',
        artistId: artistId,
        artistName: artist.name,
        date: day,
        organizerName: organizerName.trim(),
        organization: organizerName.trim(),
        contactPerson: '',
        email: '',
        phone: '',
        venue: venue.trim(),
        fee: fee,
        message: message.trim(),
        status: DealStatus.withArtist,
        sentAt: now,
        deadline: offerReplyDeadline(now),
      ),
    );
    _notifyArtist(artistId, organizerName.trim(), venue.trim(), day, 'booking-$_inquirySequence');
  }

  @override
  Future<List<ArtistOffer>> fetchMyOffers() async {
    _requireSession();
    _ensureSeedDeals();
    final mine = [
      for (final deal in _deals)
        if (deal.artistId == _session!.artistId &&
            !deal.archived &&
            (deal.withArtist || deal.declined))
          _offerFromDeal(deal),
    ];
    mine.sort((a, b) {
      if (a.pending != b.pending) return a.pending ? -1 : 1;
      return a.date.compareTo(b.date);
    });
    return mine;
  }

  @override
  Future<void> respondToOffer({
    required String offerId,
    required bool approve,
    String comment = '',
  }) async {
    _requireSession();
    _ensureSeedDeals();
    final index = _deals.indexWhere(
      (deal) => deal.id == offerId && deal.artistId == _session!.artistId && deal.withArtist,
    );
    if (index < 0) throw PortalException('Forespørselen finnes ikke');
    final deal = _deals[index];
    if (!deal.replyOpen(_clock())) {
      throw PortalException('Svarfristen på 48 timer er ute');
    }
    if (!approve) {
      final reason = comment.trim();
      if (reason.isEmpty) throw PortalException('Skriv hvorfor forespørselen avslås');
      _deals[index] = deal.copyWith(status: DealStatus.declined, declineComment: reason);
      return;
    }
    if (_isConfirmed(deal.artistId, deal.date)) {
      throw PortalException('Datoen er allerede booket');
    }
    _deals[index] = deal.copyWith(status: DealStatus.accepted);
  }

  @override
  Future<void> undoOfferDecline(String offerId) async {
    _requireSession();
    _ensureSeedDeals();
    final index = _deals.indexWhere(
      (deal) => deal.id == offerId && deal.artistId == _session!.artistId && deal.declined,
    );
    if (index < 0) throw PortalException('Forespørselen finnes ikke');
    final deal = _deals[index];
    if (deal.archived) {
      throw PortalException('Forespørselen er arkivert og kan ikke angres');
    }
    if (_deals.any(
      (item) =>
          item.id != deal.id &&
          item.withArtist &&
          item.replyOpen(_clock()) &&
          item.artistId == deal.artistId &&
          isSameDay(item.date, deal.date),
    )) {
      throw PortalException('Det ligger allerede et tilbud på denne datoen');
    }
    final now = _clock();
    _deals[index] = deal.copyWith(
      status: DealStatus.withArtist,
      clearDecline: true,
      clearArchived: true,
      sentAt: now,
      deadline: offerReplyDeadline(now),
    );
  }

  @override
  Future<List<ArtistOffer>> fetchDeclinedOffers() async {
    _requireAdmin();
    _ensureSeedDeals();
    final declined =
        _deals.where((deal) => deal.declined && !deal.archived).toList();
    declined.sort((a, b) => b.date.compareTo(a.date));
    return [for (final deal in declined) _offerFromDeal(deal)];
  }

  @override
  Future<BookingRequest?> fetchBookingRequest(String id) async => null;

  @override
  Stream<PushNotice> get pushNotices => _pushNotices.stream;

  List<PushNotice> get pushOutbox => List.unmodifiable(_pushOutbox);

  List<LeaderMail> get mailOutbox => List.unmodifiable(_mailOutbox);

  @override
  Future<String> pushPublicKey() async => demoVapidPublicKey;

  @override
  Future<bool> hasPushSubscription() async {
    final me = _me();
    if (me?.userId == null) return false;
    return _pushByUser.containsKey(me!.userId);
  }

  @override
  Future<void> savePushSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
  }) async {
    final me = _me();
    if (me?.userId == null || !receivesBandPush(isLeader: me!.isLeader, role: me.role)) {
      throw PortalException('Bare bandleder eller admin kan slå på varsler.');
    }
    if (!endpoint.startsWith('https://') || p256dh.trim().isEmpty || auth.trim().isEmpty) {
      throw PortalException('Ugyldig push-abonnement.');
    }
    _pushByUser[me.userId!] = (endpoint: endpoint, p256dh: p256dh, auth: auth);
  }

  @override
  Future<void> removePushSubscription(String endpoint) async {
    final userId = _me()?.userId;
    if (userId == null) return;
    final current = _pushByUser[userId];
    if (current == null) return;
    if (endpoint.isEmpty || current.endpoint == endpoint) {
      _pushByUser.remove(userId);
    }
  }

  /// Køer e-post kl. 10 for gårsdagens konserter som ikke er bekreftet.
  List<LeaderMail> enqueueSetlistReminders({DateTime? at}) {
    final moment = at ?? _clock();
    if (moment.hour != 10) return const [];
    final yesterday = addCalendarDays(moment, -1);
    final created = <LeaderMail>[];
    for (final gig in _gigs) {
      if (!isSameDay(dateOnly(gig.date), yesterday)) continue;
      if (_setlists[gig.id]?.confirmed == true) continue;
      final before = _mailOutbox.length;
      _enqueueLeaderMail(
        artistId: gig.artistId,
        dedupePrefix: 'setlist:${gig.id}:${formatIsoDate(yesterday)}',
        subject: setlistPushTitle,
        body: setlistPushBody,
        url: setlistPushUrl(gig.id),
      );
      if (_mailOutbox.length > before) {
        created.addAll(_mailOutbox.skip(before));
      }
    }
    return created;
  }

  void _enqueueLeaderMail({
    required String artistId,
    required String dedupePrefix,
    required String subject,
    required String body,
    required String url,
  }) {
    final band = _band;
    if (band == null || band.artistId != artistId) return;
    final emails = bandLeaderEmails([
      for (final member in _members.where((member) => member.bandId == band.id))
        (isLeader: member.isLeader, role: member.role, email: member.email),
    ]);
    for (final email in emails) {
      final dedupeKey = '$dedupePrefix:$email';
      if (_mailOutbox.any((item) => item.dedupeKey == dedupeKey)) continue;
      _mailOutbox.add(
        LeaderMail(
          to: email,
          subject: subject,
          body: body,
          url: url,
          dedupeKey: dedupeKey,
        ),
      );
    }
  }

  PressKit _seedPressKit() {
    final artist = _artist(DemoCatalog.linnId);
    return PressKit(
      artistId: DemoCatalog.linnId,
      artistName: artist?.name ?? 'Rolffa',
      slug: artistSlug(artist?.name ?? 'Rolffa'),
      bio:
          'Rolffa er et band som bookes til klubber, kulturhus og festivaler. Denne teksten er den offisielle biografien til presse.',
      spotifyUri: artist?.spotifyUri ?? '',
      photos: const [null, null, null],
    );
  }

  PressKit _publicKit(Artist artist) {
    if (artist.id == _pressKit.artistId) {
      return _pressKit.copyWith(spotifyUri: artist.spotifyUri);
    }
    return PressKit.empty(
      artistId: artist.id,
      artistName: artist.name,
      slug: artistSlug(artist.name),
      spotifyUri: artist.spotifyUri,
    );
  }

  Artist? _artistBySlug(String slug) {
    final needle = slug.trim().toLowerCase();
    for (final artist in DemoCatalog.artists) {
      if (artistSlug(artist.name) == needle || artist.id == slug.trim()) return artist;
    }
    return null;
  }

  @override
  Future<PressKit?> fetchMyPressKit() async {
    final me = _me();
    if (me == null || _band?.artistId != _session?.artistId) return null;
    final artist = _artist(_pressKit.artistId);
    return _pressKit.copyWith(spotifyUri: artist?.spotifyUri ?? _pressKit.spotifyUri);
  }

  @override
  Future<PressKit> savePressBio(String bio) async {
    final current = await fetchMyPressKit();
    if (current == null) throw PortalException('Opprett bandet før du lager pressepakke.');
    _pressKit = current.copyWith(bio: bio.trim());
    return _pressKit;
  }

  @override
  Future<PressKit> savePressPhoto({
    required int slot,
    required String filename,
    required Uint8List bytes,
  }) async {
    final current = await fetchMyPressKit();
    if (current == null) throw PortalException('Opprett bandet før du lager pressepakke.');
    final checked = checkedPressPhoto(slot: slot, filename: filename, bytes: bytes);
    final photos = List<PressPhoto?>.of(current.photos);
    photos[slot - 1] = PressPhoto(
      slot: slot,
      path: 'band-rolffa/press-$slot${pressPhotoExtension(checked.contentType)}',
      contentType: checked.contentType,
      bytes: bytes,
    );
    _pressKit = current.copyWith(photos: photos);
    return _pressKit;
  }

  @override
  Future<Uint8List> downloadPressPhoto(PressPhoto photo) async {
    final bytes = photo.bytes ?? _pressKit.photo(photo.slot)?.bytes;
    if (bytes == null) throw PortalException('Pressebildet kunne ikke hentes.');
    return bytes;
  }

  @override
  Future<PressKit?> fetchPublicPressKit(String slug) async {
    final artist = _artistBySlug(slug);
    if (artist == null || !(_published[artist.id] ?? true)) return null;
    return _publicKit(artist);
  }

  @override
  Future<List<VenueNote>> fetchVenueNotes() async {
    if (_me() == null || _band == null) return const [];
    final notes = List<VenueNote>.of(_venueNotes);
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<VenueNote> addVenueNote({
    required String venueName,
    required String city,
    required String loadInNotes,
    required String soundLightingNotes,
    required String hospitalityNotes,
    required String contactNotes,
  }) async {
    final band = _band;
    if (_me() == null || band == null) {
      throw PortalException('Logg inn som bandmedlem for å lagre notatet.');
    }
    if (venueName.trim().isEmpty) throw PortalException('Skriv navnet på spillestedet.');
    _venueNoteSequence += 1;
    final now = _clock();
    final note = VenueNote(
      id: 'note-$_venueNoteSequence',
      bandId: band.id,
      venueName: venueName.trim(),
      city: city.trim(),
      loadInNotes: loadInNotes.trim(),
      soundLightingNotes: soundLightingNotes.trim(),
      hospitalityNotes: hospitalityNotes.trim(),
      contactNotes: contactNotes.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _venueNotes.add(note);
    return note;
  }

  Gig _ownGig(String gigId) {
    for (final gig in _gigs) {
      if (gig.id == gigId && gig.artistId == _session!.artistId) return gig;
    }
    throw PortalException('Fant ikke konserten.');
  }

  void _ensureSeedDeals() {
    if (_dealReady) return;
    _dealReady = true;
    final sent = _clock();
    _deals.add(
      BookingDeal(
        id: 'offer-demo-1',
        artistId: DemoCatalog.linnId,
        artistName: 'Rolffa',
        date: DateTime(2026, 10, 24),
        organizerName: 'Oslo Live',
        organization: 'Oslo Live',
        contactPerson: 'Kari',
        email: 'kari@example.com',
        phone: '900 00 000',
        venue: 'Parkteatret, Oslo',
        fee: 90000,
        message: 'Tilbud om kveldskonsert.',
        status: DealStatus.withArtist,
        sentAt: sent,
        deadline: offerReplyDeadline(sent),
      ),
    );
    _deals.add(
      BookingDeal(
        id: 'booking-demo-inquiry',
        artistId: DemoCatalog.linnId,
        artistName: 'Rolffa',
        date: DateTime(2026, 12, 5),
        organizerName: 'Studentersamfundet',
        organization: 'Studentersamfundet',
        contactPerson: 'Eva Berg',
        email: 'booking@samfundet.no',
        phone: '900 50 050',
        venue: 'Studentersamfundet, Trondheim',
        notes: 'Lørdagskonsert. Pris er ikke avtalt ennå.',
      ),
    );
  }

  ArtistOffer _offerFromDeal(BookingDeal deal) {
    return ArtistOffer(
      id: deal.id,
      artistId: deal.artistId,
      date: deal.date,
      fee: deal.fee ?? 0,
      venue: deal.venue,
      organizerName: deal.organizerName,
      message: deal.message,
      status: deal.declined ? 'declined' : 'pending',
      declineComment: deal.declineComment,
      artistName: deal.artistName,
      deadline: deal.deadline,
      bookingId: deal.id,
    );
  }

  void _notifyArtist(
    String artistId,
    String organizer,
    String venue,
    DateTime date,
    String dealId,
  ) {
    _enqueueLeaderMail(
      artistId: artistId,
      dedupePrefix: 'offer:$dealId:${date.millisecondsSinceEpoch}',
      subject: bookingPushTitle,
      body: bookingPushBody(organizer: organizer, venue: venue, date: date),
      url: '/min-side',
    );
  }

  int _dealIndex(String id) => _deals.indexWhere((deal) => deal.id == id);

  @override
  Future<List<BookingDeal>> fetchDeals() async {
    _requireAdmin();
    _ensureSeedDeals();
    final deals = [
      for (final deal in _deals)
        if (!deal.archived) _withCrew(deal),
    ];
    deals.sort((a, b) => a.date.compareTo(b.date));
    return deals;
  }

  @override
  Future<List<BookingDeal>> fetchArchivedDeals() async {
    _requireAdmin();
    _ensureSeedDeals();
    final deals = [
      for (final deal in _deals)
        if (deal.archived) _withCrew(deal),
    ];
    deals.sort((a, b) {
      final left = a.archivedAt ?? a.date;
      final right = b.archivedAt ?? b.date;
      return right.compareTo(left);
    });
    return deals;
  }

  @override
  Future<void> archiveDeal(String dealId) async {
    _requireAdmin();
    _ensureSeedDeals();
    final index = _dealIndex(dealId);
    if (index < 0) throw PortalException('Forespørselen finnes ikke');
    final deal = _deals[index];
    if (!deal.declined) {
      throw PortalException('Bare avslåtte forespørsler kan arkiveres');
    }
    if (deal.archived) return;
    _deals[index] = deal.copyWith(archivedAt: _clock());
  }

  @override
  Future<void> unarchiveDeal(String dealId) async {
    _requireAdmin();
    _ensureSeedDeals();
    final index = _dealIndex(dealId);
    if (index < 0) throw PortalException('Forespørselen finnes ikke');
    final deal = _deals[index];
    if (!deal.archived) return;
    if (!deal.declined) {
      throw PortalException('Bare arkiverte avslag kan tas ut av arkivet');
    }
    _deals[index] = deal.copyWith(clearArchived: true);
  }

  BookingDeal _withCrew(BookingDeal deal) {
    if (deal.gigId.isEmpty) return deal;
    final crew = _crewByGig[deal.gigId];
    if (crew == null) return deal;
    return deal.copyWith(crew: List<CrewLeg>.of(crew));
  }

  @override
  Future<void> sendDealToArtist({
    required String dealId,
    required int fee,
    required String message,
  }) async {
    _requireAdmin();
    if (fee < 0) throw PortalException('Honorar må være 0 eller høyere');
    _ensureSeedDeals();
    final index = _dealIndex(dealId);
    if (index < 0) throw PortalException('Forespørselen finnes ikke');
    final deal = _deals[index];
    final expired = deal.withArtist && !deal.replyOpen(_clock());
    if (!deal.inquiry && !deal.declined && !expired) {
      throw PortalException('Forespørselen kan ikke sendes til artisten nå');
    }
    if (_isConfirmed(deal.artistId, deal.date)) {
      throw PortalException('Artisten er allerede booket denne datoen');
    }
    final now = _clock();
    _deals[index] = deal.copyWith(
      fee: fee,
      message: message.trim(),
      status: DealStatus.withArtist,
      clearDecline: true,
      sentAt: now,
      deadline: offerReplyDeadline(now),
    );
    _notifyArtist(deal.artistId, deal.organizerName, deal.venue, deal.date, deal.id);
  }

  @override
  Future<void> signDeal(String dealId) async {
    _requireAdmin();
    _ensureSeedDeals();
    final index = _dealIndex(dealId);
    if (index < 0) throw PortalException('Forespørselen finnes ikke');
    final deal = _deals[index];
    if (!deal.accepted) throw PortalException('Artisten må si ja før kontrakten kan signeres');
    _deals[index] = deal.copyWith(
      status: DealStatus.adminSigned,
      adminSignedAt: _clock(),
    );
  }

  @override
  Future<void> confirmDeal(String dealId) async {
    _requireAdmin();
    _ensureSeedDeals();
    final index = _dealIndex(dealId);
    if (index < 0) throw PortalException('Forespørselen finnes ikke');
    final deal = _deals[index];
    if (!deal.accepted && !deal.adminSigned && !deal.declined) {
      throw PortalException('Forespørselen kan ikke bekreftes ennå');
    }
    if (_isConfirmed(deal.artistId, deal.date)) {
      throw PortalException('Artisten er allerede booket denne datoen');
    }
    final gigId = 'gig-${deal.id}';
    final travelToken = 'reise-${deal.id}';
    final dayToken = 'dag-${deal.id}';
    _gigs.add(
      Gig(
        id: gigId,
        bookingId: deal.id,
        bookingToken: 'produksjon-$gigId',
        artistId: deal.artistId,
        artistName: deal.artistName,
        date: deal.date,
        status: 'confirmed',
        organizer: Organizer(
          name: deal.organizerName,
          organization: deal.organization,
          contactPerson: deal.contactPerson,
          email: deal.email,
          phone: deal.phone,
          venueCity: deal.venue,
          notes: deal.notes,
        ),
        production: ProductionPlan(
          notes: deal.message,
          nearestAirport: deal.airport,
          airportDistance: deal.airportDistance,
          travelRoute: deal.route,
          callTime: deal.callTime,
        ),
      ),
    );
    _crewByGig[gigId] = _defaultCrew(deal.artistId, deal.artistName);
    _overrides[_overrideKey(deal.artistId, deal.date)] = false;
    _deals[index] = deal.copyWith(
      status: DealStatus.confirmed,
      adminSignedAt: deal.adminSignedAt ?? _clock(),
      gigId: gigId,
      travelToken: travelToken,
      dayToken: dayToken,
      pressReady: true,
      crew: List<CrewLeg>.of(_crewByGig[gigId]!),
    );
  }

  List<CrewLeg> _defaultCrew(String artistId, String artistName) {
    if (_band != null && _band!.artistId == artistId) {
      return [
        for (final member in _members)
          CrewLeg(
            memberId: member.id,
            name: member.name,
            role: member.role,
            leader: member.isLeader,
          ),
      ];
    }
    return [
      CrewLeg(
        memberId: 'artist-$artistId',
        name: artistName,
        role: 'Artist',
        leader: true,
      ),
    ];
  }

  BookingDeal? _dealByToken(String token, bool travel) {
    _ensureSeedDeals();
    for (final deal in _deals) {
      final value = travel ? deal.travelToken : deal.dayToken;
      if (value.isNotEmpty && value == token) return _withCrew(deal);
    }
    return null;
  }

  @override
  Future<BookingDeal?> fetchDealByTravelToken(String token) async => _dealByToken(token, true);

  @override
  Future<void> saveOrganizerTravel({
    required String token,
    required String airport,
    required String distance,
    String route = '',
  }) async {
    final index = _deals.indexWhere((deal) => deal.travelToken == token && deal.confirmed);
    if (index < 0) throw PortalException('Lenken finnes ikke');
    if (airport.trim().isEmpty || distance.trim().isEmpty) {
      throw PortalException('Flyplass og avstand må fylles ut');
    }
    final before = _deals[index];
    final wasReady = before.travelBriefReady;
    final deal = before.copyWith(
      airport: airport.trim(),
      airportDistance: distance.trim(),
      route: route.trim(),
    );
    _deals[index] = deal;
    _paintGig(deal);
    if (!wasReady && deal.travelBriefReady) {
      _enqueueLeaderMail(
        artistId: deal.artistId,
        dedupePrefix: 'travel:${deal.id}',
        subject: travelBookPushTitle,
        body: travelBookPushBody(venue: deal.venue, date: deal.date),
        url: deal.gigId.isEmpty ? '/min-side' : travelBookPushUrl(deal.gigId),
      );
    }
  }

  @override
  Future<BookingDeal?> fetchDealByDayToken(String token) async => _dealByToken(token, false);

  @override
  Future<void> saveOrganizerDay({
    required String token,
    required TimeOfDay getIn,
    required TimeOfDay soundcheck,
    required TimeOfDay showStart,
    required String dinnerPlace,
    required String hotelName,
    required String hotelAddress,
    required String notes,
  }) async {
    final index = _deals.indexWhere((deal) => deal.dayToken == token && deal.confirmed);
    if (index < 0) throw PortalException('Lenken finnes ikke');
    if (hotelAddress.trim().isEmpty) {
      throw PortalException('Adressen til overnattingsstedet må fylles ut');
    }
    final deal = _deals[index].copyWith(
      getIn: getIn,
      soundcheck: soundcheck,
      showStart: showStart,
      dinnerPlace: dinnerPlace.trim(),
      hotelName: hotelName.trim(),
      hotelAddress: hotelAddress.trim(),
      dayNotes: notes.trim(),
      daySheetReady: true,
    );
    _deals[index] = deal;
    _paintGig(deal);
  }

  void _paintGig(BookingDeal deal) {
    final gigIndex = _gigs.indexWhere((gig) => gig.id == deal.gigId);
    if (gigIndex < 0) return;
    final gig = _gigs[gigIndex];
    _gigs[gigIndex] = gig.copyWith(
      production: gig.production.copyWith(
        nearestAirport: deal.airport,
        airportDistance: deal.airportDistance,
        travelRoute: deal.route,
        callTime: deal.callTime,
        getIn: deal.getIn,
        soundcheck: deal.soundcheck,
        showStart: deal.showStart,
        accommodationName: deal.hotelName,
        accommodationAddress: deal.hotelAddress,
        dinnerVenueName: deal.dinnerPlace,
        notes: deal.dayNotes.isEmpty ? gig.production.notes : deal.dayNotes,
        daySheetReady: deal.daySheetReady,
      ),
    );
  }

  List<CrewLeg> _crewForSessionGig(String gigId) {
    _requireSession();
    final gig = _ownGig(gigId);
    return _crewByGig.putIfAbsent(gig.id, () => _defaultCrew(gig.artistId, gig.artistName));
  }

  void _syncDealCrew(String gigId) {
    final crew = _crewByGig[gigId];
    if (crew == null) return;
    final index = _deals.indexWhere((deal) => deal.gigId == gigId);
    if (index < 0) return;
    _deals[index] = _deals[index].copyWith(crew: List<CrewLeg>.of(crew));
  }

  @override
  Future<List<CrewLeg>> fetchCrewTravel(String gigId) async {
    return List<CrewLeg>.of(_crewForSessionGig(gigId));
  }

  @override
  Future<List<CrewLeg>> saveCrewTravel({
    required String gigId,
    required String memberId,
    required DateTime arrival,
    required DateTime departure,
    required String pickup,
    required String dropoff,
  }) async {
    if (pickup.trim().isEmpty || dropoff.trim().isEmpty) {
      throw PortalException('Ankomst, hentested, avreise og avleveringssted må fylles ut.');
    }
    final gig = _ownGig(gigId);
    if (!gig.production.travelBriefReady) {
      throw PortalException(
        'Arrangøren må fylle ut flyplass og avstand før reisen kan bestilles.',
      );
    }
    final crew = _crewForSessionGig(gigId);
    final me = _me();
    final index = crew.indexWhere((leg) => leg.memberId == memberId && leg.active);
    if (index < 0) throw PortalException('Medlemmet er ikke med på denne konserten');
    final leg = crew[index];
    if (me == null || (!me.isLeader && me.id != leg.memberId)) {
      throw PortalException('Du kan bare fylle inn din egen reise');
    }
    crew[index] = leg.copyWith(
      arrival: arrival,
      departure: departure,
      pickup: pickup.trim(),
      dropoff: dropoff.trim(),
      booked: true,
    );
    _syncDealCrew(gigId);
    return List<CrewLeg>.of(crew);
  }

  @override
  Future<List<CrewLeg>> setCrewMemberActive({
    required String gigId,
    required String memberId,
    required bool active,
  }) async {
    final me = _me();
    if (me == null || !me.isLeader) {
      throw PortalException('Bare bandlederen kan endre hvem som er med');
    }
    final crew = _crewForSessionGig(gigId);
    final index = crew.indexWhere((leg) => leg.memberId == memberId);
    if (index < 0) throw PortalException('Fant ikke medlemmet');
    if (!active && crew.where((leg) => leg.active && leg.memberId != memberId).isEmpty) {
      throw PortalException('Minst én person må være med på konserten');
    }
    final leg = crew[index];
    crew[index] = CrewLeg(
      memberId: leg.memberId,
      name: leg.name,
      role: leg.role,
      leader: leg.leader,
      active: active,
      booked: active ? leg.booked : false,
      arrival: active ? leg.arrival : null,
      departure: active ? leg.departure : null,
      pickup: active ? leg.pickup : '',
      dropoff: active ? leg.dropoff : '',
    );
    _syncDealCrew(gigId);
    return List<CrewLeg>.of(crew);
  }
}

