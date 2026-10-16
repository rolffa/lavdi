import 'package:flutter/material.dart';

import '../core/format.dart';

abstract final class DealStatus {
  static const inquiry = 'inquiry';
  static const withArtist = 'with_artist';
  static const declined = 'declined';
  static const accepted = 'accepted';
  static const adminSigned = 'admin_signed';
  static const confirmed = 'confirmed';
}

class CrewLeg {
  const CrewLeg({
    required this.memberId,
    required this.name,
    required this.role,
    this.leader = false,
    this.active = true,
    this.booked = false,
    this.arrival,
    this.departure,
    this.pickup = '',
    this.dropoff = '',
  });

  final String memberId;
  final String name;
  final String role;
  final bool leader;
  final bool active;
  final bool booked;
  final DateTime? arrival;
  final DateTime? departure;
  final String pickup;
  final String dropoff;

  CrewLeg copyWith({
    bool? active,
    bool? booked,
    DateTime? arrival,
    DateTime? departure,
    String? pickup,
    String? dropoff,
  }) {
    return CrewLeg(
      memberId: memberId,
      name: name,
      role: role,
      leader: leader,
      active: active ?? this.active,
      booked: booked ?? this.booked,
      arrival: arrival ?? this.arrival,
      departure: departure ?? this.departure,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
    );
  }

  factory CrewLeg.fromJson(Map<String, dynamic> json) {
    return CrewLeg(
      memberId: json['member_id'].toString(),
      name: (json['navn'] as String?)?.trim() ?? '',
      role: (json['rolle'] as String?)?.trim() ?? '',
      leader: json['er_leder'] as bool? ?? false,
      active: json['aktiv'] as bool? ?? true,
      booked: json['bestilt'] as bool? ?? false,
      arrival: _timestamp(json['arrival_time']),
      departure: _timestamp(json['departure_time']),
      pickup: (json['pickup_location'] as String?)?.trim() ?? '',
      dropoff: (json['dropoff_location'] as String?)?.trim() ?? '',
    );
  }

  static DateTime? _timestamp(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class BookingDeal {
  const BookingDeal({
    required this.id,
    required this.artistId,
    required this.artistName,
    required this.date,
    required this.organizerName,
    required this.organization,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.venue,
    this.notes = '',
    this.fee,
    this.message = '',
    this.status = DealStatus.inquiry,
    this.declineComment = '',
    this.sentAt,
    this.deadline,
    this.adminSignedAt,
    this.gigId = '',
    this.travelToken = '',
    this.dayToken = '',
    this.pressReady = false,
    this.route = '',
    this.airport = '',
    this.airportDistance = '',
    this.callTime,
    this.daySheetReady = false,
    this.hotelName = '',
    this.hotelAddress = '',
    this.getIn,
    this.soundcheck,
    this.showStart,
    this.dinnerPlace = '',
    this.dayNotes = '',
    this.crew = const [],
    this.archivedAt,
  });

  final String id;
  final String artistId;
  final String artistName;
  final DateTime date;
  final String organizerName;
  final String organization;
  final String contactPerson;
  final String email;
  final String phone;
  final String venue;
  final String notes;
  final int? fee;
  final String message;
  final String status;
  final String declineComment;
  final DateTime? sentAt;
  final DateTime? deadline;
  final DateTime? adminSignedAt;
  final String gigId;
  final String travelToken;
  final String dayToken;
  final bool pressReady;
  final String route;
  final String airport;
  final String airportDistance;
  final TimeOfDay? callTime;
  final bool daySheetReady;
  final String hotelName;
  final String hotelAddress;
  final TimeOfDay? getIn;
  final TimeOfDay? soundcheck;
  final TimeOfDay? showStart;
  final String dinnerPlace;
  final String dayNotes;
  final List<CrewLeg> crew;
  final DateTime? archivedAt;

  bool get inquiry => status == DealStatus.inquiry;
  bool get withArtist => status == DealStatus.withArtist;
  bool get declined => status == DealStatus.declined;
  bool get accepted => status == DealStatus.accepted;
  bool get adminSigned => status == DealStatus.adminSigned;
  bool get confirmed => status == DealStatus.confirmed;
  bool get archived => archivedAt != null;

  bool replyOpen(DateTime now) => deadline == null || now.isBefore(deadline!);

  bool get travelBriefReady =>
      airport.trim().isNotEmpty && airportDistance.trim().isNotEmpty;

  BookingDeal copyWith({
    int? fee,
    String? message,
    String? status,
    String? declineComment,
    DateTime? sentAt,
    DateTime? deadline,
    DateTime? adminSignedAt,
    String? gigId,
    String? travelToken,
    String? dayToken,
    bool? pressReady,
    String? route,
    String? airport,
    String? airportDistance,
    TimeOfDay? callTime,
    bool? daySheetReady,
    String? hotelName,
    String? hotelAddress,
    TimeOfDay? getIn,
    TimeOfDay? soundcheck,
    TimeOfDay? showStart,
    String? dinnerPlace,
    String? dayNotes,
    List<CrewLeg>? crew,
    DateTime? archivedAt,
    bool clearDecline = false,
    bool clearArchived = false,
  }) {
    return BookingDeal(
      id: id,
      artistId: artistId,
      artistName: artistName,
      date: date,
      organizerName: organizerName,
      organization: organization,
      contactPerson: contactPerson,
      email: email,
      phone: phone,
      venue: venue,
      notes: notes,
      fee: fee ?? this.fee,
      message: message ?? this.message,
      status: status ?? this.status,
      declineComment: clearDecline ? '' : (declineComment ?? this.declineComment),
      sentAt: sentAt ?? this.sentAt,
      deadline: deadline ?? this.deadline,
      adminSignedAt: adminSignedAt ?? this.adminSignedAt,
      gigId: gigId ?? this.gigId,
      travelToken: travelToken ?? this.travelToken,
      dayToken: dayToken ?? this.dayToken,
      pressReady: pressReady ?? this.pressReady,
      route: route ?? this.route,
      airport: airport ?? this.airport,
      airportDistance: airportDistance ?? this.airportDistance,
      callTime: callTime ?? this.callTime,
      daySheetReady: daySheetReady ?? this.daySheetReady,
      hotelName: hotelName ?? this.hotelName,
      hotelAddress: hotelAddress ?? this.hotelAddress,
      getIn: getIn ?? this.getIn,
      soundcheck: soundcheck ?? this.soundcheck,
      showStart: showStart ?? this.showStart,
      dinnerPlace: dinnerPlace ?? this.dinnerPlace,
      dayNotes: dayNotes ?? this.dayNotes,
      crew: crew ?? this.crew,
      archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
    );
  }

  factory BookingDeal.fromJson(Map<String, dynamic> json) {
    final date = json['dato'];
    final fee = json['honorar'];
    final crew = json['crew'];
    return BookingDeal(
      id: json['id'].toString(),
      artistId: json['artist_id'].toString(),
      artistName: (json['artist_navn'] as String?)?.trim() ?? '',
      date: date is DateTime ? dateOnly(date) : parseIsoDate(date.toString()),
      organizerName: (json['arrangor_navn'] as String?)?.trim() ?? '',
      organization: (json['organisasjon'] as String?)?.trim() ?? '',
      contactPerson: (json['kontaktperson'] as String?)?.trim() ?? '',
      email: (json['epost'] as String?)?.trim() ?? '',
      phone: (json['telefon'] as String?)?.trim() ?? '',
      venue: (json['spillested'] as String?)?.trim() ?? '',
      notes: (json['notater'] as String?)?.trim() ?? '',
      fee: fee is num ? fee.toInt() : null,
      message: (json['melding'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? DealStatus.inquiry,
      declineComment: (json['avslag_kommentar'] as String?)?.trim() ?? '',
      sentAt: _timestamp(json['sendt_artist_at']),
      deadline: _timestamp(json['svarfrist']),
      adminSignedAt: _timestamp(json['admin_signert_at']),
      gigId: (json['gig_id'] as String?)?.trim() ?? '',
      travelToken: (json['reise_token'] as String?)?.trim() ?? '',
      dayToken: (json['dag_token'] as String?)?.trim() ?? '',
      pressReady: json['presse_klar'] as bool? ?? false,
      route: (json['reiserute'] as String?)?.trim() ?? '',
      airport: (json['flyplass'] as String?)?.trim() ?? '',
      airportDistance: (json['avstand'] as String?)?.trim() ?? '',
      callTime: parseClock(json['oppmote']),
      daySheetReady: json['dagskjema'] as bool? ?? false,
      hotelName: (json['hotell_navn'] as String?)?.trim() ?? '',
      hotelAddress: (json['hotell_adresse'] as String?)?.trim() ?? '',
      getIn: parseClock(json['get_in']),
      soundcheck: parseClock(json['lydprove']),
      showStart: parseClock(json['showstart']),
      dinnerPlace: (json['middag_sted'] as String?)?.trim() ?? '',
      dayNotes: (json['dag_notater'] as String?)?.trim() ?? '',
      crew: [
        if (crew is List)
          for (final item in crew)
            if (item is Map) CrewLeg.fromJson(Map<String, dynamic>.from(item)),
      ],
      archivedAt: _timestamp(json['arkivert_at']),
    );
  }

  static DateTime? _timestamp(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
