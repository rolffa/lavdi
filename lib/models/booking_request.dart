import '../core/format.dart';

class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.artistName,
    required this.date,
    required this.organizerName,
    required this.organization,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.venue,
    required this.notes,
  });

  final String id;
  final String artistName;
  final DateTime date;
  final String organizerName;
  final String organization;
  final String contactPerson;
  final String email;
  final String phone;
  final String venue;
  final String notes;

  factory BookingRequest.fromJson(Map<String, dynamic> json) {
    return BookingRequest(
      id: json['id'] as String,
      artistName: (json['artist_navn'] as String?)?.trim() ?? '',
      date: parseIsoDate(json['dato'] as String),
      organizerName: (json['arrangor_navn'] as String?)?.trim() ?? '',
      organization: (json['organisasjon'] as String?)?.trim() ?? '',
      contactPerson: (json['kontaktperson'] as String?)?.trim() ?? '',
      email: (json['epost'] as String?)?.trim() ?? '',
      phone: (json['telefon'] as String?)?.trim() ?? '',
      venue: (json['spillested'] as String?)?.trim() ?? '',
      notes: (json['notater'] as String?)?.trim() ?? '',
    );
  }
}
