import '../core/format.dart';

/// A band member who is booked with another band on the same date.
class MemberDateConflict {
  const MemberDateConflict({
    required this.memberId,
    required this.memberName,
    required this.memberRole,
    required this.otherBandId,
    required this.otherBandName,
    required this.otherArtistId,
    required this.otherArtistName,
    required this.date,
    this.gigId,
  });

  final String memberId;
  final String memberName;
  final String memberRole;
  final String otherBandId;
  final String otherBandName;
  final String otherArtistId;
  final String otherArtistName;
  final DateTime date;
  final String? gigId;

  String get label {
    final who = memberName.trim().isEmpty ? 'Et medlem' : memberName.trim();
    final role = memberRole.trim();
    final band = otherBandName.trim().isNotEmpty
        ? otherBandName.trim()
        : (otherArtistName.trim().isEmpty ? 'et annet band' : otherArtistName.trim());
    if (role.isEmpty) {
      return '$who er opptatt med $band ${formatLongDate(date)}.';
    }
    return '$who ($role) er opptatt med $band ${formatLongDate(date)}.';
  }

  factory MemberDateConflict.fromJson(Map<String, dynamic> json) {
    return MemberDateConflict(
      memberId: json['member_id']?.toString() ?? '',
      memberName: (json['member_navn'] as String?)?.trim() ?? '',
      memberRole: (json['member_rolle'] as String?)?.trim() ?? '',
      otherBandId: json['other_band_id']?.toString() ?? '',
      otherBandName: (json['other_band_navn'] as String?)?.trim() ?? '',
      otherArtistId: json['other_artist_id']?.toString() ?? '',
      otherArtistName: (json['other_artist_navn'] as String?)?.trim() ?? '',
      date: parseIsoDate(json['dato'].toString()),
      gigId: json['gig_id']?.toString(),
    );
  }
}

List<MemberDateConflict> parseMemberConflicts(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final row in raw)
      if (row is Map)
        MemberDateConflict.fromJson(Map<String, dynamic>.from(row)),
  ];
}
