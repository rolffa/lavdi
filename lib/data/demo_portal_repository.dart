import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
import '../models/member_conflict.dart';
import '../models/musician_band.dart';
import '../models/press_kit.dart';
import '../models/leader_mail.dart';
import '../models/push_notice.dart';
import '../models/production_plan.dart';
import '../models/stage_plot.dart';
import '../models/venue_note.dart';
import 'demo_catalog.dart';
import 'portal_repository.dart';

class DemoPortalRepository extends PortalRepository {
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
  ArtistSession? _adminViewAsArtist;
  String? _adminSecret;
  final List<RepertoireTrack> _repertoire = [];
  final Map<String, ConcertSetlist> _setlists = {};
  var _trackSequence = 1;
  var _memberSequence = 1;
  Band? _band = const Band(
    id: 'band-rolffa',
    artistId: DemoCatalog.linnId,
    name: 'Rolffa',
    contact: 'rolffa@lavdi.no',
    sharedTech: '',
    sharedHospitality: '',
  );
  final List<BandMember> _members = [
    const BandMember(
      id: 'member-rolffa',
      bandId: 'band-rolffa',
      userId: 'user-rolffa',
      name: 'Rolffa',
      role: 'Bandleder',
      phone: '',
      food: '',
      personalTech: '',
      email: DemoCatalog.artistEmail,
      isLeader: true,
    ),
  ];
  final List<BandInvite> _invites = [];
  StagePlot? _stagePlot;
  final Map<String, List<CrewLeg>> _crewByGig = {};
  final Map<String, ({String endpoint, String p256dh, String auth})> _pushByUser = {};
  final List<PushNotice> _pushOutbox = [];
  final List<LeaderMail> _mailOutbox = [];
  final StreamController<PushNotice> _pushNotices = StreamController<PushNotice>.broadcast();
  var _inquirySequence = 0;
  var _venueNoteSequence = 1;
  late PressKit _pressKit = _seedPressKit();
  final List<VenueNote> _venueNotes = [];

  List<Gig> _seedGigs() => [];

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

  String _adminUsername = '';
  String _adminAuthEmail = '';
  String _adminPassword = DemoCatalog.adminPassword;
  String? _adminAvatarUrl;
  String? _myAvatarUrl;
  String _artistPassword = DemoCatalog.artistPassword;

  @override
  bool get isAdminSignedIn => _adminSecret != null;

  @override
  String get adminUsername => _adminUsername;

  @override
  String get adminAuthEmail => _adminAuthEmail;

  @override
  Future<void> signInAdmin({required String username, required String password}) async {
    final name = username.trim().toLowerCase();
    if (name != DemoCatalog.adminUsername || password != _adminPassword) {
      throw PortalException('Feil brukernavn eller passord');
    }
    _adminSecret = password;
    _adminUsername = name;
    _adminAuthEmail = DemoCatalog.adminEmail;
  }

  @override
  void signOutAdmin() {
    _adminSecret = null;
    _adminUsername = '';
    _adminAuthEmail = '';
    if (_adminViewAsArtist != null) {
      _adminViewAsArtist = null;
      _session = null;
    }
    notifyListeners();
  }

  @override
  ArtistSession? get adminViewAsArtist => _adminViewAsArtist;

  @override
  Future<void> preparePublicArtistEntry() async {
    _adminViewAsArtist = null;
    notifyListeners();
  }

  @override
  Future<ArtistSession> openArtistPortalAsAdmin(String artistId) async {
    _requireAdmin();
    final artist = _artist(artistId);
    if (artist == null) throw PortalException('Fant ikke artisten.');
    final session = ArtistSession(
      artistId: artist.id,
      artistName: artist.name,
      email: _adminAuthEmail,
      asAdmin: true,
    );
    _adminViewAsArtist = session;
    _session = session;
    notifyListeners();
    return session;
  }

  @override
  Future<void> closeArtistPortalAsAdmin() async {
    _requireAdmin();
    _adminViewAsArtist = null;
    _session = null;
    notifyListeners();
  }

  @override
  Future<void> changeAdminPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _requireAdmin();
    if (currentPassword != _adminPassword) {
      throw PortalException('Nåværende passord er feil');
    }
    if (newPassword.trim().length < 6) {
      throw PortalException('Nytt passord må være minst 6 tegn');
    }
    _adminPassword = newPassword.trim();
    _adminSecret = _adminPassword;
  }

  @override
  Future<String?> fetchAdminAvatarUrl() async {
    _requireAdmin();
    return _adminAvatarUrl;
  }

  @override
  Future<String> uploadAdminAvatar({
    required String filename,
    required Uint8List bytes,
  }) async {
    _requireAdmin();
    if (bytes.isEmpty) throw PortalException('Velg et bilde');
    _adminAvatarUrl = 'demo-admin-avatar:${bytes.length}:$filename';
    return _adminAvatarUrl!;
  }

  @override
  Future<void> changeArtistPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _requireSession();
    if (currentPassword != _artistPassword) {
      throw PortalException('Nåværende passord er feil');
    }
    if (newPassword.trim().length < 6) {
      throw PortalException('Nytt passord må være minst 6 tegn');
    }
    _artistPassword = newPassword.trim();
  }

  @override
  Future<void> setArtistPassword(String password) async {
    _requireSession();
    if (password.trim().length < 6) {
      throw PortalException('Passordet må være minst 6 tegn');
    }
    _artistPassword = password.trim();
  }

  @override
  Future<String?> fetchMyAvatarUrl() async {
    _requireSession();
    return _myAvatarUrl;
  }

  @override
  Future<String> uploadMyAvatar({
    required String filename,
    required Uint8List bytes,
  }) async {
    _requireSession();
    if (bytes.isEmpty) throw PortalException('Velg et bilde');
    _myAvatarUrl = 'demo-avatar:${bytes.length}:$filename';
    return _myAvatarUrl!;
  }

  @override
  Future<List<BandMember>> fetchAdminBandAccounts(String artistId) async {
    _requireAdmin();
    final band = _band;
    if (band == null || band.artistId != artistId) return const [];
    return [
      for (final member in _members.where((m) => m.bandId == band.id))
        member,
    ];
  }

  @override
  Future<BandInvite> adminInviteBandMember({
    required String artistId,
    required String email,
    required String role,
    bool asLeader = false,
  }) async {
    _requireAdmin();
    final artist = _artist(artistId);
    if (artist == null) throw PortalException('Fant ikke artisten');
    if (_band == null || _band!.artistId != artistId) {
      _band = Band(
        id: 'band-$artistId',
        artistId: artistId,
        name: artist.name,
        contact: '',
        sharedTech: '',
        sharedHospitality: '',
      );
    }
    final address = email.trim().toLowerCase();
    final crewRole = asLeader ? 'Bandleder' : role.trim();
    if (!address.contains('@')) {
      throw PortalException('Oppgi en gyldig e-postadresse.');
    }
    if (crewRole.isEmpty) throw PortalException('Oppgi en rolle.');
    final existing = _invites.indexWhere(
      (invite) => !invite.accepted && invite.email.toLowerCase() == address,
    );
    final invite = BandInvite(
      id: existing >= 0 ? _invites[existing].id : 'invite-${_memberSequence++}',
      bandId: _band!.id,
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
  Future<void> adminRemoveBandMember({
    required String artistId,
    required String memberId,
  }) async {
    _requireAdmin();
    _members.removeWhere((item) => item.id == memberId);
  }

  @override
  Future<void> adminSendPasswordReset(String email) async {
    _requireAdmin();
    final address = email.trim().toLowerCase();
    if (!address.contains('@')) {
      throw PortalException('Oppgi en gyldig e-postadresse.');
    }
    // Demo: ingen mailserver – lagres bare som vellykket handling.
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
  Future<ArtistSession?> currentArtist() async =>
      _adminViewAsArtist ?? _session;

  @override
  Future<ArtistSession> signInArtist({
    required String email,
    required String password,
  }) async {
    final address = email.trim().toLowerCase();
    if (password != _artistPassword) {
      throw PortalException('Feil e-post eller passord');
    }
    if (address == DemoCatalog.artistEmail) {
      _session = _rolffaSession();
      return _session!;
    }
    BandMember? member;
    for (final item in _members) {
      if (item.email.toLowerCase() == address) {
        member = item;
        break;
      }
    }
    if (member == null || _band == null) {
      throw PortalException('Feil e-post eller passord');
    }
    _session = ArtistSession(
      artistId: _band!.artistId ?? '',
      artistName: _band!.name,
      email: member.email,
    );
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
    if (_adminViewAsArtist != null) {
      await closeArtistPortalAsAdmin();
      return;
    }
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
      invites: _invites.where((invite) => !invite.accepted).toList(),
    );
  }

  void _replaceMember(BandMember member) {
    final index = _members.indexWhere((item) => item.id == member.id);
    if (index >= 0) _members[index] = member;
  }

  @override
  Future<List<String>> fetchBandNotifyEmails(String artistId) async {
    final band = _band;
    if (band == null || band.artistId != artistId) return const [];
    return bandMemberEmails([
      for (final member in _members.where((m) => m.bandId == band.id))
        (isLeader: member.isLeader, role: member.role, email: member.email),
    ]);
  }

  @override
  Future<BandOverview?> fetchMyBand() async {
    final view = _adminViewAsArtist;
    if (view != null) {
      final artist = _artist(view.artistId);
      if (artist == null) return null;
      final band = (_band?.artistId == artist.id)
          ? _band!
          : Band(
              id: 'admin-view-${artist.id}',
              artistId: artist.id,
              name: artist.name,
              contact: '',
              sharedTech: '',
              sharedHospitality: '',
            );
      final me = BandMember(
        id: 'admin-view-me',
        bandId: band.id,
        name: 'Admin',
        role: 'Admin',
        phone: '',
        food: '',
        personalTech: '',
        email: view.email,
        isLeader: true,
      );
      final members = _band?.artistId == artist.id
          ? List<BandMember>.of(_members)
          : <BandMember>[me];
      return BandOverview(
        band: band,
        me: me,
        members: members.isEmpty ? [me] : members,
        invites: _band?.artistId == artist.id
            ? _invites.where((invite) => !invite.accepted).toList()
            : const [],
      );
    }
    return _overview();
  }

  @override
  Future<List<MusicianBand>> fetchMyBands() async {
    final overview = await fetchMyBand();
    if (overview == null) return const [];
    return [
      MusicianBand(
        bandId: overview.band.id,
        bandName: overview.band.name,
        artistId: overview.band.artistId ?? _session?.artistId ?? '',
        artistName: overview.band.name,
        role: overview.me.role,
        isActive: true,
      ),
    ];
  }

  @override
  Future<void> setActiveBand(String bandId) async {
    notifyListeners();
  }

  @override
  Future<List<CombinedCalendarMark>> fetchCombinedCalendar({
    required DateTime from,
    required DateTime to,
  }) async {
    final overview = await fetchMyBand();
    final session = await currentArtist();
    if (overview == null || session == null) return const [];
    final days = await fetchAvailability(
      artistId: session.artistId,
      from: from,
      to: to,
    );
    return [
      for (final day in days)
        CombinedCalendarMark(
          date: dateOnly(day.date),
          bandId: overview.band.id,
          bandName: overview.band.name,
          artistId: session.artistId,
          isAvailable: day.isAvailable,
          isBooked: day.isBooked,
        ),
    ];
  }

  @override
  Future<BandOverview> ensureMyBand() async {
    final session = await currentArtist();
    if (session == null) throw PortalException('Logg inn på nytt.');
    if (_band?.artistId == session.artistId) {
      final existing = await fetchMyBand();
      if (existing != null) return existing;
    }
    return createBand(name: session.artistName, contact: '');
  }

  @override
  Future<BandOverview> createBand({required String name, required String contact}) async {
    _requireSession();
    final artistId = _session!.artistId;
    if (_band?.artistId == artistId) {
      final existing = await fetchMyBand();
      if (existing != null) return existing;
    }
    final bandName =
        name.trim().isEmpty ? _session!.artistName : name.trim();
    if (bandName.isEmpty) throw PortalException('Bandet trenger et navn.');
    final band = Band(
      id: 'band-${_memberSequence++}',
      artistId: artistId,
      name: bandName,
      contact: contact.trim(),
      sharedTech: '',
      sharedHospitality: '',
    );
    _band = band;
    // Bandleder kommer via første invitasjon — ikke auto-opprettet artist-sete.
    final overview = await fetchMyBand();
    if (overview == null) throw PortalException('Bandet ble ikke opprettet.');
    return overview;
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
    if (me == null || band == null) {
      throw PortalException('Du er ikke med i et band.');
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
    if (me == null || band == null) {
      throw PortalException('Du er ikke med i et band.');
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
    if (me == null || band == null) {
      throw PortalException('Du er ikke med i et band.');
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
    if (me == null || band == null) {
      throw PortalException('Du er ikke med i et band.');
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
  Future<void> removeMember(String memberId) async {
    _requireSession();
    final overview = await fetchMyBand();
    if (overview == null) {
      throw PortalException('Du er ikke med i et band.');
    }
    BandMember? member;
    for (final item in overview.members) {
      if (item.id == memberId) member = item;
    }
    if (member == null) throw PortalException('Fant ikke medlemmet.');
    _members.removeWhere((item) => item.id == memberId);
  }

  @override
  Future<BandInvite> inviteMember({required String email, required String role}) async {
    _requireSession();
    final me = _me();
    final band = _band;
    if ((me == null && _adminViewAsArtist == null) || band == null) {
      throw PortalException('Du er ikke med i et band.');
    }
    final address = email.trim().toLowerCase();
    var crewRole = role.trim();
    if (!address.contains('@')) throw PortalException('Oppgi en gyldig e-postadresse.');
    if (crewRole.isEmpty) throw PortalException('Oppgi en rolle.');
    if (_members.isEmpty) crewRole = 'Bandleder';
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
    await sendInviteEmail(invite.token);
    return invite;
  }

  @override
  Future<void> sendInviteEmail(String token) async {
    final preview = await previewInvite(token);
    if (preview == null) throw PortalException('Invitasjonen finnes ikke.');
    if (preview.used) throw PortalException('Invitasjonen er allerede brukt.');
    // Demo: ingen ekte e-post. Produksjon bruker Edge Function send-invite-email.
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    _requireSession();
    if (_me() == null) {
      throw PortalException('Du er ikke med i et band.');
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
  String? currentAuthEmail() => _session?.email ?? _adminViewAsArtist?.email;

  @override
  Future<String?> waitForAuthEmail({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return currentAuthEmail();
  }

  @override
  Future<BandMember> acceptInvite(String token) async {
    final index = _invites.indexWhere((invite) => invite.token == token);
    if (index < 0 || _band == null) {
      throw PortalException('Invitasjonen finnes ikke.');
    }
    final invite = _invites[index];
    final asLeader = _members.isEmpty ||
        invite.role.toLowerCase() == 'bandleder' ||
        invite.role.toLowerCase() == 'leder';
    final role = _members.isEmpty ? 'Bandleder' : invite.role;
    BandMember? member;
    for (final item in _members) {
      if (item.email.toLowerCase() == invite.email.toLowerCase()) member = item;
    }
    member ??= BandMember(
      id: 'member-${_memberSequence++}',
      bandId: _band!.id,
      userId: 'user-${invite.email}',
      name: '',
      role: role,
      phone: '',
      food: '',
      personalTech: '',
      email: invite.email,
      isLeader: asLeader,
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
  Future<List<MemberDateConflict>> fetchMemberConflicts({
    required String artistId,
    required DateTime date,
  }) async {
    return const [];
  }

  @override
  Future<List<MemberDateConflict>> fetchMyBandBusyNotices() async {
    return const [];
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
    final userId = me?.userId;
    if (userId == null || userId.isEmpty) {
      throw PortalException('Du er ikke med i et band.');
    }
    if (!endpoint.startsWith('https://') || p256dh.trim().isEmpty || auth.trim().isEmpty) {
      throw PortalException('Ugyldig push-abonnement.');
    }
    _pushByUser[userId] = (endpoint: endpoint, p256dh: p256dh, auth: auth);
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
    final emails = bandMemberEmails([
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
    final session = _session ?? _adminViewAsArtist;
    if (session == null) return null;
    final overview = await fetchMyBand();
    if (overview == null) return null;
    final artistId = overview.band.artistId ?? session.artistId;
    final artist = _artist(artistId);
    final name = artist?.name ?? session.artistName;
    return PressKit(
      artistId: artistId,
      artistName: name,
      slug: artistSlug(name),
      bio: _pressKit.bio,
      spotifyUri: artist?.spotifyUri ?? _pressKit.spotifyUri,
      photos: _pressKit.photos,
    );
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
  }

  /// Test helper: insert a confirmed gig without going through the booking flow.
  @visibleForTesting
  void debugAddConfirmedGig(Gig gig) {
    _gigs.add(gig);
    _overrides[_overrideKey(gig.artistId, dateOnly(gig.date))] = false;
    _crewByGig.putIfAbsent(
      gig.id,
      () => _defaultCrew(gig.artistId, gig.artistName),
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
    if (me == null) {
      throw PortalException('Du er ikke med i et band.');
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

