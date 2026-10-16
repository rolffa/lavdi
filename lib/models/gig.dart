import '../core/format.dart';
import 'gig_travel.dart';
import 'production_plan.dart';

class Gig {
  const Gig({
    required this.id,
    required this.bookingId,
    required this.bookingToken,
    required this.artistId,
    required this.artistName,
    required this.date,
    required this.status,
    required this.organizer,
    required this.production,
    this.travel = const GigTravel.unbooked(),
  });

  final String id;
  final String bookingId;
  final String bookingToken;
  final String artistId;
  final String artistName;
  final DateTime date;
  final String status;
  final Organizer organizer;
  final ProductionPlan production;
  final GigTravel travel;

  bool get productionReady => status == 'ready';

  Gig copyWith({String? status, ProductionPlan? production, GigTravel? travel}) {
    return Gig(
      id: id,
      bookingId: bookingId,
      bookingToken: bookingToken,
      artistId: artistId,
      artistName: artistName,
      date: date,
      status: status ?? this.status,
      organizer: organizer,
      production: production ?? this.production,
      travel: travel ?? this.travel,
    );
  }

  factory Gig.fromJson(Map<String, dynamic> json) {
    return Gig(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      bookingToken: json['booking_token'] as String,
      artistId: json['artist_id'] as String,
      artistName: json['artist_navn'] as String? ?? '',
      date: parseIsoDate(json['dato'] as String),
      status: json['status'] as String,
      organizer: Organizer.fromJson(asMap(json['arrangor'])),
      production: ProductionPlan.fromJson(asMap(json['produksjon'])),
      travel: GigTravel.fromJson(json),
    );
  }
}

Map<String, dynamic>? asMap(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
