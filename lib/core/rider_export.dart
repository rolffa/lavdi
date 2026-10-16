import '../models/band.dart';
import 'format.dart';

enum RiderExport { complete, technical, hospitality }

class ProfileGap {
  const ProfileGap({required this.name, required this.missing});

  final String name;
  final List<String> missing;

  String get sentence {
    final who = name.trim().isEmpty ? 'Uten navn' : name.trim();
    return '$who mangler ${missing.join(', ')}.';
  }
}

List<ProfileGap> riderProfileGaps(RiderExport kind, List<BandMember> members) {
  final checkFood = kind != RiderExport.technical;
  final checkTech = kind != RiderExport.hospitality;
  final gaps = <ProfileGap>[];
  for (final member in sortedRiderMembers(members)) {
    final missing = <String>[];
    if (member.phone.trim().isEmpty) missing.add('telefon');
    if (checkFood && member.food.trim().isEmpty) missing.add('diett');
    if (checkTech && member.personalTech.trim().isEmpty) missing.add('personlig teknikk');
    if (missing.isEmpty) continue;
    gaps.add(
      ProfileGap(
        name: member.name.trim().isEmpty ? 'Uten navn' : member.name.trim(),
        missing: missing,
      ),
    );
  }
  return gaps;
}

String riderBandSlug(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Band';
  final slug = trimmed
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
  return slug.isEmpty ? 'Band' : slug;
}

String riderPdfFileName(RiderExport kind, String bandName, DateTime date) {
  final prefix = switch (kind) {
    RiderExport.complete => 'Rider_Komplett',
    RiderExport.technical => 'Teknisk_Rider',
    RiderExport.hospitality => 'Hospitality_Rider',
  };
  return '${prefix}_${riderBandSlug(bandName)}_${formatIsoDate(date)}.pdf';
}

List<BandMember> sortedRiderMembers(List<BandMember> members) {
  final copy = List<BandMember>.of(members);
  copy.sort((a, b) {
    if (a.isLeader != b.isLeader) return a.isLeader ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return copy;
}
