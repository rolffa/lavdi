import '../core/format.dart';

class ArtistOffer {
  const ArtistOffer({
    required this.id,
    required this.artistId,
    required this.date,
    required this.fee,
    required this.venue,
    required this.organizerName,
    required this.message,
    this.status = 'pending',
    this.declineComment = '',
    this.artistName = '',
    this.deadline,
    this.bookingId = '',
  });

  final String id;
  final String artistId;
  final DateTime date;
  final int fee;
  final String venue;
  final String organizerName;
  final String message;
  final String status;
  final String declineComment;
  final String artistName;
  final DateTime? deadline;
  final String bookingId;

  bool get pending => status == 'pending';
  bool get declined => status == 'declined';

  bool replyOpen(DateTime now) => deadline == null || now.isBefore(deadline!);

  factory ArtistOffer.fromJson(Map<String, dynamic> json) {
    final date = json['dato'];
    return ArtistOffer(
      id: json['id'].toString(),
      artistId: json['artist_id'].toString(),
      date: date is DateTime ? dateOnly(date) : parseIsoDate(date.toString()),
      fee: (json['honorar'] as num).toInt(),
      venue: (json['spillested'] as String?)?.trim() ?? '',
      organizerName: (json['arrangor_navn'] as String?)?.trim() ?? '',
      message: (json['melding'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? 'pending',
      declineComment: (json['avslag_kommentar'] as String?)?.trim() ?? '',
      artistName: (json['artist_navn'] as String?)?.trim() ?? '',
      deadline: _timestamp(json['svarfrist']),
      bookingId: (json['booking_id'] as String?)?.trim() ?? '',
    );
  }

  static DateTime? _timestamp(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
