import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/artist_slug.dart';
import '../core/errors.dart';
import '../core/format.dart';
import '../core/tono.dart';
import '../data/demo_catalog.dart';
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
import 'portal_repository.dart';

class SupabasePortalRepository implements PortalRepository {
  SupabasePortalRepository(this._client);

  final SupabaseClient _client;
  final StreamController<PushNotice> _pushNotices = StreamController<PushNotice>.broadcast();

  static const _artistColumns =
      'id, navn, tagline, bio, bilde_url, video_url, spotify_uri, minstepris, publisert';

  @override
  Future<List<Artist>> fetchArtists() async {
    final rows = await _client
        .from('artists')
        .select(_artistColumns)
        .eq('publisert', true)
        .order('navn');
    return rows.map(Artist.fromRow).toList();
  }

  @override
  Future<Artist?> fetchArtist(String id) async {
    final row = await _client
        .from('artists')
        .select(_artistColumns)
        .eq('id', id)
        .eq('publisert', true)
        .maybeSingle();
    if (row == null) return null;
    return Artist.fromRow(row);
  }

  @override
  Future<List<Artist>> fetchAdminArtists() async {
    final pin = _requireAdmin();
    try {
      final result = await _client.rpc(
        'admin_list_artists',
        params: {'p_pin': pin},
      );
      if (result is! List) return const [];
      return [
        for (final row in result)
          if (row is Map) Artist.fromRow(Map<String, dynamic>.from(row)),
      ];
    } on PostgrestException catch (error) {
      throw _adminError(error);
    }
  }

  @override
  Future<void> setArtistPublished({
    required String artistId,
    required bool published,
  }) async {
    final pin = _requireAdmin();
    try {
      await _client.rpc(
        'admin_set_artist_published',
        params: {
          'p_pin': pin,
          'p_artist_id': artistId,
          'p_publisert': published,
        },
      );
    } on PostgrestException catch (error) {
      throw _adminError(error);
    }
  }

  @override
  Future<List<AvailabilityDay>> fetchAvailability({
    required String artistId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client.rpc(
      'availability_for_artist',
      params: {
        'p_artist_id': artistId,
        'p_from': formatIsoDate(from),
        'p_to': formatIsoDate(to),
      },
    );
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        AvailabilityDay(
          date: parseIsoDate((row as Map)['dato'] as String),
          isAvailable: row['er_tilgjengelig'] as bool? ?? false,
          isBooked: row['er_booket'] as bool? ??
              !(row['er_tilgjengelig'] as bool? ?? true),
        ),
    ];
  }

  @override
  Future<void> saveMyAvailability({
    required List<DateTime> dates,
    required bool available,
  }) async {
    if (dates.isEmpty) return;
    await _client.rpc(
      'save_artist_availability',
      params: {
        'p_dates': [for (final date in dates) formatIsoDate(date)],
        'p_status': available ? 'available' : 'unavailable',
      },
    );
  }

  @override
  Future<void> submitBooking(BookingDraft draft) async {
    await _client.from('bookings').insert({
      'artist_id': draft.artistId,
      'dato': formatIsoDate(draft.date),
      'status': 'inquiry',
      'arrangor_navn': draft.organizerName.trim(),
      'organisasjon': draft.organization.trim(),
      'kontaktperson': draft.contactPerson.trim(),
      'epost': draft.email.trim(),
      'telefon': draft.phone.trim(),
      'spillested': draft.venueCity.trim(),
      'notater': draft.notes.trim(),
    });
  }

  @override
  Future<Gig?> fetchGig(String bookingToken) async {
    final result = await _client.rpc(
      'get_gig_by_token',
      params: {'p_token': bookingToken},
    );
    if (result == null) return null;
    return Gig.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<Gig> saveProduction({
    required String bookingToken,
    required ProductionPlan plan,
  }) async {
    final result = await _client.rpc(
      'save_production_plan',
      params: {
        'p_token': bookingToken,
        'p_produksjon': plan.toJson(),
      },
    );
    if (result == null) {
      throw PortalException('Fant ingen jobb for denne lenken.');
    }
    return Gig.fromJson(Map<String, dynamic>.from(result as Map));
  }

  bool _adminSignedIn = false;
  String? _adminSecret;

  @override
  bool get isAdminSignedIn => _adminSignedIn;

  @override
  Future<void> signInAdmin({required String username, required String password}) async {
    final name = username.trim();
    if (name.isEmpty || password.isEmpty) {
      throw PortalException('Skriv brukernavn og passord');
    }
    final ok = await _adminPasswordMatches(name, password);
    if (!ok) throw PortalException('Feil brukernavn eller passord');
    _adminSecret = password;
    _adminSignedIn = true;
  }

  @override
  void signOutAdmin() {
    _adminSecret = null;
    _adminSignedIn = false;
  }

  String _requireAdmin() {
    final secret = _adminSecret;
    if (secret == null) throw PortalException('Logg inn på nytt.');
    return secret;
  }

  Future<bool> _adminPasswordMatches(String username, String password) async {
    try {
      final result = await _client.rpc(
        'admin_sign_in',
        params: {'p_username': username, 'p_password': password},
      );
      return result == true;
    } on PostgrestException catch (error) {
      final missing = error.code == 'PGRST202' || error.message.contains('admin_sign_in');
      if (!missing) throw _adminError(error);
      if (username.trim().toLowerCase() != DemoCatalog.adminUsername) return false;
      final result = await _client.rpc('admin_check_pin', params: {'p_pin': password});
      return result == true;
    }
  }

  @override
  Future<void> setAvailability({
    required String artistId,
    required DateTime date,
    required bool isAvailable,
  }) async {
    final pin = _requireAdmin();
    try {
      await _client.rpc(
        'admin_set_availability',
        params: {
          'p_pin': pin,
          'p_artist_id': artistId,
          'p_dato': formatIsoDate(date),
          'p_ledig': isAvailable,
        },
      );
    } on PostgrestException catch (error) {
      throw _adminError(error);
    }
  }

  PortalException _adminError(PostgrestException error) {
    if (error.code == 'PGRST202') {
      return PortalException(
        'Admin-funksjonen finnes ikke i databasen ennå. Kjør supabase/admin_calendar.sql og supabase/artist_publish.sql.',
      );
    }
    final message = error.message.trim();
    if (message.isNotEmpty) return PortalException(message);
    return PortalException('Noe gikk galt. Prøv igjen.');
  }

  @override
  Future<ArtistSession?> currentArtist() async {
    if (_client.auth.currentSession == null) return null;
    return _loadArtist();
  }

  @override
  Future<ArtistSession> signInArtist({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthException {
      throw PortalException('Feil e-post eller passord');
    }
    final artist = await _loadArtist();
    if (artist == null) {
      await _client.auth.signOut();
      throw PortalException('Ingen artist er koblet til denne brukeren.');
    }
    return artist;
  }

  @override
  Future<bool> sendArtistLink(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: '${Uri.base.origin}/min-side',
      );
    } on AuthException {
      throw PortalException('Kunne ikke sende innloggingslenken.');
    }
    return false;
  }

  @override
  Future<void> signOutArtist() async {
    await _client.auth.signOut();
  }

  Future<ArtistSession?> _loadArtist() async {
    final result = await _client.rpc('artist_me');
    if (result == null) return null;
    final json = Map<String, dynamic>.from(result as Map);
    final artistId = json['artist_id'] as String?;
    final name = json['navn'] as String?;
    if (artistId == null || name == null) return null;
    return ArtistSession(
      artistId: artistId,
      artistName: name,
      email: (json['epost'] as String?) ?? _client.auth.currentUser?.email ?? '',
    );
  }

  Future<ArtistSession> _requireArtist() async {
    final artist = await currentArtist();
    if (artist == null) throw PortalException('Logg inn på nytt.');
    return artist;
  }

  @override
  Future<List<Gig>> fetchMyGigs() async {
    final artist = await _requireArtist();
    final rows = await _client
        .from('gigs')
        .select(
          'id, booking_id, booking_token, artist_id, dato, status, arrangor, produksjon, travel_status, arrival_time, pickup_location, departure_time, dropoff_location',
        )
        .eq('artist_id', artist.artistId)
        .order('dato');
    return [
      for (final row in rows)
        Gig.fromJson({
          ...row,
          'artist_navn': artist.artistName,
        }),
    ];
  }

  @override
  Future<List<RepertoireTrack>> fetchRepertoire() async {
    final artist = await _requireArtist();
    final rows = await _client
        .from('repertoire')
        .select('id, tittel, spilletid')
        .eq('artist_id', artist.artistId)
        .order('tittel');
    return rows.map(RepertoireTrack.fromJson).toList();
  }

  @override
  Future<RepertoireTrack> saveRepertoireTrack({
    String? id,
    required String title,
    required String duration,
  }) async {
    final artist = await _requireArtist();
    final playTime = normalizePlayTime(duration);
    if (title.trim().isEmpty || playTime == null) {
      throw PortalException('Tittel og spilletid på formen 03:45 må fylles ut.');
    }
    final payload = {
      'artist_id': artist.artistId,
      'tittel': title.trim(),
      'spilletid': playTime,
    };
    final Map<String, dynamic> row;
    if (id == null || id.isEmpty) {
      row = await _client.from('repertoire').insert(payload).select().single();
    } else {
      row = await _client.from('repertoire').update(payload).eq('id', id).select().single();
    }
    return RepertoireTrack.fromJson(row);
  }

  @override
  Future<void> deleteRepertoireTrack(String id) async {
    await _requireArtist();
    await _client.from('repertoire').delete().eq('id', id);
  }

  @override
  Future<ConcertSetlist> fetchSetlist(String gigId) async {
    await _requireArtist();
    final row = await _client.from('setlists').select().eq('gig_id', gigId).maybeSingle();
    if (row == null) return ConcertSetlist.empty(gigId);
    final tracks = (row['spor'] as List? ?? const [])
        .map((item) => SetlistTrack.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return ConcertSetlist(
      gigId: gigId,
      tracks: tracks,
      confirmed: row['bekreftet_at'] != null,
      tonoText: (row['tono_tekst'] as String?) ?? '',
    );
  }

  @override
  Future<ConcertSetlist> saveSetlist({
    required String gigId,
    required List<SetlistTrack> tracks,
  }) async {
    final artist = await _requireArtist();
    if (tracks.isEmpty) throw PortalException('Huk av minst én låt.');
    final tonoText = formatTonoSetlist(tracks);
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('setlists').upsert({
      'gig_id': gigId,
      'artist_id': artist.artistId,
      'spor': tracks.map((track) => track.toJson()).toList(),
      'tono_tekst': tonoText,
      'bekreftet_at': now,
      'updated_at': now,
    });
    return ConcertSetlist(
      gigId: gigId,
      tracks: tracks,
      confirmed: true,
      tonoText: tonoText,
    );
  }

  @override
  Future<BandOverview?> fetchMyBand() async {
    if (_client.auth.currentSession == null) return null;
    await _client.rpc('attach_band_leader');
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final mine = await _client.from('band_members').select().eq('user_id', userId).maybeSingle();
    if (mine == null) return null;
    final bandId = mine['band_id'] as String;
    final bandRow = await _client.from('bands').select().eq('id', bandId).single();
    final memberRows = await _client.from('band_members').select().eq('band_id', bandId).order('navn');
    final me = BandMember.fromJson(Map<String, dynamic>.from(mine));
    final invites = <BandInvite>[];
    if (me.isLeader) {
      final inviteRows = await _client
          .from('band_invites')
          .select()
          .eq('band_id', bandId)
          .isFilter('accepted_at', null);
      invites.addAll(
        inviteRows.map((row) => BandInvite.fromJson(Map<String, dynamic>.from(row))),
      );
    }
    return BandOverview(
      band: Band.fromJson(Map<String, dynamic>.from(bandRow)),
      me: me,
      members: [
        for (final row in memberRows) BandMember.fromJson(Map<String, dynamic>.from(row)),
      ],
      invites: invites,
    );
  }

  @override
  Future<BandOverview> createBand({required String name, required String contact}) async {
    await _client.rpc('create_band', params: {'p_navn': name, 'p_kontakt': contact});
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
    final overview = await fetchMyBand();
    if (overview == null || !overview.me.isLeader) {
      throw PortalException('Bare bandlederen kan oppdatere bandet.');
    }
    final row = await _client
        .from('bands')
        .update({
          'navn': name.trim(),
          'kontaktinfo': contact.trim(),
          'tech_felles': sharedTech.trim(),
          'hospitality_felles': sharedHospitality.trim(),
        })
        .eq('id', overview.band.id)
        .select()
        .single();
    return Band.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<Band> saveTechnicalRider({
    required String inputList,
    required String monitors,
    required String stageRig,
    required String paRequirements,
  }) async {
    final overview = await _leaderBand();
    final row = await _client
        .from('bands')
        .update({
          'input_liste': inputList.trim(),
          'monitor': monitors.trim(),
          'scenerigg': stageRig.trim(),
          'pa_krav': paRequirements.trim(),
        })
        .eq('id', overview.band.id)
        .select()
        .single();
    return Band.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<StagePlot?> fetchStagePlot() async {
    final overview = await fetchMyBand();
    if (overview == null || overview.band.stagePlotPath.isEmpty) return null;
    final band = overview.band;
    try {
      final bytes = await _client.storage.from('stage-plots').download(band.stagePlotPath);
      final type = band.stagePlotType.isNotEmpty
          ? band.stagePlotType
          : (stagePlotContentType(band.stagePlotName) ?? 'application/octet-stream');
      return StagePlot(
        name: band.stagePlotName.isEmpty ? 'scenekart' : band.stagePlotName,
        contentType: type,
        bytes: bytes,
        path: band.stagePlotPath,
      );
    } on StorageException {
      throw PortalException('Scenekartet kunne ikke hentes.');
    }
  }

  @override
  Future<StagePlot> uploadStagePlot({
    required String filename,
    required Uint8List bytes,
  }) async {
    final overview = await _leaderBand();
    final checked = checkedStagePlot(filename: filename, bytes: bytes);
    final path = '${overview.band.id}/stage-plot${checked.fileExtension}';
    final previous = overview.band.stagePlotPath;
    try {
      await _client.storage.from('stage-plots').uploadBinary(
        path,
        checked.bytes,
        fileOptions: FileOptions(contentType: checked.contentType, upsert: true),
      );
      if (previous.isNotEmpty && previous != path) {
        await _client.storage.from('stage-plots').remove([previous]);
      }
    } on StorageException {
      throw PortalException('Scenekartet kunne ikke lagres.');
    }
    final row = await _client
        .from('bands')
        .update({
          'stage_plot_path': path,
          'stage_plot_name': checked.name,
          'stage_plot_type': checked.contentType,
        })
        .eq('id', overview.band.id)
        .select()
        .single();
    final band = Band.fromJson(Map<String, dynamic>.from(row));
    return StagePlot(
      name: band.stagePlotName,
      contentType: band.stagePlotType,
      bytes: checked.bytes,
      path: band.stagePlotPath,
    );
  }

  @override
  Future<void> clearStagePlot() async {
    final overview = await _leaderBand();
    final path = overview.band.stagePlotPath;
    if (path.isNotEmpty) {
      try {
        await _client.storage.from('stage-plots').remove([path]);
      } on StorageException {
        throw PortalException('Scenekartet kunne ikke fjernes.');
      }
    }
    await _client
        .from('bands')
        .update({
          'stage_plot_path': null,
          'stage_plot_name': null,
          'stage_plot_type': null,
        })
        .eq('id', overview.band.id);
  }

  Future<BandOverview> _leaderBand() async {
    final overview = await fetchMyBand();
    if (overview == null || !overview.me.isLeader) {
      throw PortalException('Bare bandlederen kan oppdatere rideren.');
    }
    return overview;
  }

  @override
  Future<BandMember> saveMyProfile({
    required String name,
    required String role,
    required String phone,
    required String food,
    required String personalTech,
  }) async {
    if (name.trim().isEmpty ||
        role.trim().isEmpty ||
        phone.trim().isEmpty ||
        food.trim().isEmpty ||
        personalTech.trim().isEmpty) {
      throw PortalException('Navn, rolle, telefon, mat og tekniske behov må fylles ut.');
    }
    final overview = await fetchMyBand();
    if (overview == null) throw PortalException('Du er ikke med i et band.');
    final row = await _client
        .from('band_members')
        .update({
          'navn': name.trim(),
          'rolle': role.trim(),
          'telefon': phone.trim(),
          'mat': food.trim(),
          'tech_personlig': personalTech.trim(),
        })
        .eq('id', overview.me.id)
        .select()
        .single();
    return BandMember.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<BandInvite> inviteMember({required String email, required String role}) async {
    final result = await _client.rpc(
      'invite_band_member',
      params: {'p_email': email.trim(), 'p_rolle': role.trim()},
    );
    return BandInvite.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<void> sendInviteEmail(String token) async {
    final preview = await previewInvite(token);
    if (preview == null) throw PortalException('Invitasjonen finnes ikke.');
    if (preview.used) throw PortalException('Invitasjonen er allerede brukt.');
    try {
      await _client.auth.signInWithOtp(
        email: preview.email,
        emailRedirectTo: '${Uri.base.origin}/min-side/invitasjon/$token',
        shouldCreateUser: true,
      );
    } on AuthException {
      throw PortalException('Kunne ikke sende aktiveringslenken.');
    }
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    await _client.from('band_invites').delete().eq('id', inviteId);
  }

  @override
  Future<BandInvitePreview?> previewInvite(String token) async {
    final result = await _client.rpc('invite_preview', params: {'p_token': token});
    if (result == null) return null;
    return BandInvitePreview.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<BandMember> acceptInvite(String token) async {
    await _client.rpc('accept_band_invite', params: {'p_token': token});
    final overview = await fetchMyBand();
    if (overview == null) throw PortalException('Kontoen ble ikke koblet til bandet.');
    return overview.me;
  }

  @override
  Future<BandRoster?> fetchRiders(String bookingToken) async {
    final result = await _client.rpc('riders_for_token', params: {'p_token': bookingToken});
    if (result == null) return null;
    final json = Map<String, dynamic>.from(result as Map);
    final memberJson = json['medlemmer'];
    final members = <BandMember>[];
    if (memberJson is List) {
      for (final item in memberJson) {
        members.add(BandMember.fromJson(Map<String, dynamic>.from(item as Map)));
      }
    }
    return BandRoster(
      band: Band.fromJson(json),
      members: members,
    );
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
    final pin = _requireAdmin();
    await _client.rpc(
      'admin_send_offer',
      params: {
        'p_pin': pin,
        'p_artist_id': artistId,
        'p_dato': formatIsoDate(date),
        'p_honorar': fee,
        'p_spillested': venue.trim(),
        'p_arrangor': organizerName.trim(),
        'p_melding': message.trim(),
      },
    );
  }

  @override
  Future<List<ArtistOffer>> fetchMyOffers() async {
    final result = await _client.rpc('my_offers');
    if (result is! List) return const [];
    return [
      for (final item in result)
        if (item is Map) ArtistOffer.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<void> respondToOffer({
    required String offerId,
    required bool approve,
    String comment = '',
  }) async {
    await _client.rpc(
      'respond_to_offer',
      params: {
        'p_offer_id': offerId,
        'p_approve': approve,
        'p_comment': comment.trim(),
      },
    );
  }

  @override
  Future<void> undoOfferDecline(String offerId) async {
    await _client.rpc('undo_offer_decline', params: {'p_offer_id': offerId});
  }

  @override
  Future<List<ArtistOffer>> fetchDeclinedOffers() async {
    final pin = _requireAdmin();
    final result = await _client.rpc('admin_declined_offers', params: {'p_pin': pin});
    if (result is! List) return const [];
    return [
      for (final item in result)
        if (item is Map) ArtistOffer.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<BookingRequest?> fetchBookingRequest(String id) async {
    final result = await _client.rpc('booking_request_for_me', params: {'p_id': id});
    if (result == null) return null;
    if (result is! Map) return null;
    return BookingRequest.fromJson(Map<String, dynamic>.from(result));
  }

  @override
  Stream<PushNotice> get pushNotices => _pushNotices.stream;

  @override
  Future<String> pushPublicKey() async {
    final result = await _client.rpc('push_vapid_public_key');
    return (result as String?)?.trim() ?? '';
  }

  @override
  Future<bool> hasPushSubscription() async {
    final rows = await _client.from('user_push_subscriptions').select('id').limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> savePushSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
  }) async {
    await _client.rpc(
      'save_push_subscription',
      params: {
        'p_endpoint': endpoint,
        'p_p256dh': p256dh,
        'p_auth': auth,
      },
    );
  }

  @override
  Future<void> removePushSubscription(String endpoint) async {
    await _client.rpc(
      'delete_push_subscription',
      params: {'p_endpoint': endpoint},
    );
  }

  PressPhoto? _pressPhoto(int slot, String? path) {
    final stored = path?.trim() ?? '';
    if (stored.isEmpty) return null;
    return PressPhoto(
      slot: slot,
      path: stored,
      publicUrl: _client.storage.from('press-kits').getPublicUrl(stored),
      contentType: pressPhotoContentType(stored) ?? 'image/jpeg',
    );
  }

  PressKit _pressKitFromRow({
    required Artist artist,
    Map<String, dynamic>? row,
  }) {
    return PressKit(
      artistId: artist.id,
      artistName: artist.name,
      slug: artistSlug(artist.name),
      bio: (row?['bio'] as String?)?.trim() ?? '',
      spotifyUri: artist.spotifyUri,
      photos: [
        _pressPhoto(1, row?['press_photo_1'] as String?),
        _pressPhoto(2, row?['press_photo_2'] as String?),
        _pressPhoto(3, row?['press_photo_3'] as String?),
      ],
    );
  }

  @override
  Future<PressKit?> fetchMyPressKit() async {
    final overview = await fetchMyBand();
    final artistId = overview?.band.artistId;
    if (overview == null || artistId == null) return null;
    final artist = await fetchArtist(artistId);
    if (artist == null) return null;
    final row = await _client
        .from('band_press_kit')
        .select()
        .eq('band_id', overview.band.id)
        .maybeSingle();
    return _pressKitFromRow(
      artist: artist,
      row: row == null ? null : Map<String, dynamic>.from(row),
    );
  }

  @override
  Future<PressKit> savePressBio(String bio) async {
    final overview = await fetchMyBand();
    if (overview?.band.artistId == null) {
      throw PortalException('Opprett bandet før du lager pressepakke.');
    }
    await _client.from('band_press_kit').upsert({
      'band_id': overview!.band.id,
      'bio': bio.trim(),
    });
    final kit = await fetchMyPressKit();
    if (kit == null) throw PortalException('Pressepakken kunne ikke lagres.');
    return kit;
  }

  @override
  Future<PressKit> savePressPhoto({
    required int slot,
    required String filename,
    required Uint8List bytes,
  }) async {
    final overview = await fetchMyBand();
    final artistId = overview?.band.artistId;
    if (overview == null || artistId == null) {
      throw PortalException('Opprett bandet før du lager pressepakke.');
    }
    final checked = checkedPressPhoto(slot: slot, filename: filename, bytes: bytes);
    final path = '${overview.band.id}/press-$slot${pressPhotoExtension(checked.contentType)}';
    final existing = await _client
        .from('band_press_kit')
        .select()
        .eq('band_id', overview.band.id)
        .maybeSingle();
    final previous = (existing?['press_photo_$slot'] as String?)?.trim() ?? '';
    try {
      await _client.storage.from('press-kits').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: checked.contentType, upsert: true),
      );
      if (previous.isNotEmpty && previous != path) {
        await _client.storage.from('press-kits').remove([previous]);
      }
    } on StorageException {
      throw PortalException('Pressebildet kunne ikke lagres.');
    }
    await _client.from('band_press_kit').upsert({
      'band_id': overview.band.id,
      'press_photo_$slot': path,
    });
    final kit = await fetchMyPressKit();
    if (kit == null) throw PortalException('Pressebildet kunne ikke lagres.');
    final photos = List<PressPhoto?>.of(kit.photos);
    final saved = photos[slot - 1];
    if (saved != null) {
      photos[slot - 1] = PressPhoto(
        slot: slot,
        path: saved.path,
        publicUrl: saved.publicUrl,
        contentType: checked.contentType,
        bytes: bytes,
      );
    }
    return kit.copyWith(photos: photos);
  }

  @override
  Future<Uint8List> downloadPressPhoto(PressPhoto photo) async {
    if (photo.bytes != null) return photo.bytes!;
    try {
      return await _client.storage.from('press-kits').download(photo.path);
    } on StorageException {
      throw PortalException('Pressebildet kunne ikke hentes.');
    }
  }

  @override
  Future<PressKit?> fetchPublicPressKit(String slug) async {
    final result = await _client.rpc('press_kit_for_slug', params: {'p_slug': slug});
    if (result == null || result is! Map) return null;
    final row = Map<String, dynamic>.from(result);
    final artistId = row['artist_id'] as String?;
    final name = (row['navn'] as String?)?.trim() ?? '';
    if (artistId == null || name.isEmpty) return null;
    return PressKit(
      artistId: artistId,
      artistName: name,
      slug: (row['slug'] as String?)?.trim().isNotEmpty == true
          ? (row['slug'] as String).trim()
          : artistSlug(name),
      bio: (row['bio'] as String?)?.trim() ?? '',
      spotifyUri: (row['spotify_uri'] as String?)?.trim() ?? '',
      photos: [
        _pressPhoto(1, row['press_photo_1'] as String?),
        _pressPhoto(2, row['press_photo_2'] as String?),
        _pressPhoto(3, row['press_photo_3'] as String?),
      ],
    );
  }

  @override
  Future<List<VenueNote>> fetchVenueNotes() async {
    final overview = await fetchMyBand();
    if (overview == null) return const [];
    final rows = await _client
        .from('venue_notes')
        .select()
        .eq('band_id', overview.band.id)
        .order('updated_at', ascending: false);
    return [
      for (final row in rows) VenueNote.fromJson(Map<String, dynamic>.from(row)),
    ];
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
    final overview = await fetchMyBand();
    if (overview == null) {
      throw PortalException('Logg inn som bandmedlem for å lagre notatet.');
    }
    if (venueName.trim().isEmpty) throw PortalException('Skriv navnet på spillestedet.');
    final row = await _client
        .from('venue_notes')
        .insert({
          'band_id': overview.band.id,
          'venue_name': venueName.trim(),
          'city': city.trim(),
          'load_in_notes': loadInNotes.trim(),
          'sound_lighting_notes': soundLightingNotes.trim(),
          'hospitality_notes': hospitalityNotes.trim(),
          'contact_notes': contactNotes.trim(),
        })
        .select()
        .single();
    return VenueNote.fromJson(Map<String, dynamic>.from(row));
  }

  List<BookingDeal> _dealsFromRpc(Object? result) {
    if (result is! List) return const [];
    return [
      for (final item in result)
        if (item is Map) BookingDeal.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  List<CrewLeg> _crewFromRpc(Object? result) {
    if (result is! List) return const [];
    return [
      for (final item in result)
        if (item is Map) CrewLeg.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<List<BookingDeal>> fetchDeals() async {
    final pin = _requireAdmin();
    final result = await _client.rpc('admin_list_deals', params: {'p_pin': pin});
    return _dealsFromRpc(result);
  }

  @override
  Future<List<BookingDeal>> fetchArchivedDeals() async {
    final pin = _requireAdmin();
    try {
      final result = await _client.rpc(
        'admin_list_archived_deals',
        params: {'p_pin': pin},
      );
      return _dealsFromRpc(result);
    } on PostgrestException catch (error) {
      throw _adminError(error);
    }
  }

  @override
  Future<void> archiveDeal(String dealId) async {
    final pin = _requireAdmin();
    try {
      await _client.rpc(
        'admin_archive_deal',
        params: {'p_pin': pin, 'p_booking_id': dealId},
      );
    } on PostgrestException catch (error) {
      throw _adminError(error);
    }
  }

  @override
  Future<void> unarchiveDeal(String dealId) async {
    final pin = _requireAdmin();
    try {
      await _client.rpc(
        'admin_unarchive_deal',
        params: {'p_pin': pin, 'p_booking_id': dealId},
      );
    } on PostgrestException catch (error) {
      throw _adminError(error);
    }
  }

  @override
  Future<void> sendDealToArtist({
    required String dealId,
    required int fee,
    required String message,
  }) async {
    final pin = _requireAdmin();
    await _client.rpc(
      'admin_send_to_artist',
      params: {
        'p_pin': pin,
        'p_booking_id': dealId,
        'p_honorar': fee,
        'p_melding': message.trim(),
      },
    );
  }

  @override
  Future<void> signDeal(String dealId) async {
    final pin = _requireAdmin();
    await _client.rpc(
      'admin_sign_deal',
      params: {'p_pin': pin, 'p_booking_id': dealId},
    );
  }

  @override
  Future<void> confirmDeal(String dealId) async {
    final pin = _requireAdmin();
    await _client.rpc(
      'admin_confirm_deal',
      params: {'p_pin': pin, 'p_booking_id': dealId},
    );
  }

  @override
  Future<BookingDeal?> fetchDealByTravelToken(String token) async {
    final result = await _client.rpc('organizer_travel_form', params: {'p_token': token});
    if (result is! Map) return null;
    return BookingDeal.fromJson(Map<String, dynamic>.from(result));
  }

  @override
  Future<void> saveOrganizerTravel({
    required String token,
    required String airport,
    required String distance,
    String route = '',
  }) async {
    await _client.rpc(
      'save_organizer_travel',
      params: {
        'p_token': token,
        'p_airport': airport.trim(),
        'p_distance': distance.trim(),
        'p_route': route.trim(),
      },
    );
  }

  @override
  Future<BookingDeal?> fetchDealByDayToken(String token) async {
    final result = await _client.rpc('organizer_day_form', params: {'p_token': token});
    if (result is! Map) return null;
    return BookingDeal.fromJson(Map<String, dynamic>.from(result));
  }

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
    await _client.rpc(
      'save_organizer_day',
      params: {
        'p_token': token,
        'p_get_in': formatClock(getIn),
        'p_soundcheck': formatClock(soundcheck),
        'p_show': formatClock(showStart),
        'p_dinner': dinnerPlace.trim(),
        'p_hotel_name': hotelName.trim(),
        'p_hotel_address': hotelAddress.trim(),
        'p_notes': notes.trim(),
      },
    );
  }

  @override
  Future<List<CrewLeg>> fetchCrewTravel(String gigId) async {
    final result = await _client.rpc('my_crew_travel', params: {'p_gig_id': gigId});
    return _crewFromRpc(result);
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
    final result = await _client.rpc(
      'save_crew_travel',
      params: {
        'p_gig_id': gigId,
        'p_member_id': memberId,
        'p_arrival': arrival.toUtc().toIso8601String(),
        'p_departure': departure.toUtc().toIso8601String(),
        'p_pickup': pickup.trim(),
        'p_dropoff': dropoff.trim(),
      },
    );
    return _crewFromRpc(result);
  }

  @override
  Future<List<CrewLeg>> setCrewMemberActive({
    required String gigId,
    required String memberId,
    required bool active,
  }) async {
    final result = await _client.rpc(
      'set_crew_member_active',
      params: {
        'p_gig_id': gigId,
        'p_member_id': memberId,
        'p_active': active,
      },
    );
    return _crewFromRpc(result);
  }
}
