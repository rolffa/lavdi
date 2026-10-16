import '../models/band.dart';
import 'input_list.dart';
import 'rider_export.dart';

enum RiderKind { hospitality, technical }

String formatHospitalityRider(Band band, List<BandMember> members) {
  final lines = <String>[
    'HOSPITALITY RIDER',
    band.name,
    '',
    'Kontakt',
    band.contact.trim().isEmpty ? 'Ikke satt' : band.contact.trim(),
    '',
    'Backstage og losji',
    band.sharedHospitality.trim().isEmpty ? 'Ikke satt' : band.sharedHospitality.trim(),
    '',
    'Mat, dietter og allergier',
  ];
  final people = sortedRiderMembers(members);
  if (people.isEmpty) {
    lines.add('Ingen profiler er utfylt ennå.');
  } else {
    for (final member in people) {
      lines.add(_heading(member));
      lines.add('Telefon');
      lines.add(member.phone.trim().isEmpty ? 'Ikke satt' : member.phone.trim());
      lines.add('Mat');
      lines.add(member.food.trim().isEmpty ? 'Ikke utfylt' : member.food.trim());
      lines.add('');
    }
  }
  return lines.join('\n').trimRight();
}

String formatTechnicalRider(Band band, List<BandMember> members) {
  final lines = <String>[
    'TEKNISK RIDER',
    band.name,
    '',
    'Kontakt',
    _text(band.contact),
    '',
    'Inputliste / patch',
    formatInputList(band.inputList),
    '',
    'Monitorbehov',
    _text(band.monitors),
    '',
    'DJ / scenerigg',
    _text(band.stageRig),
    '',
    'PA-krav',
    _text(band.paRequirements),
    '',
    'Felles teknisk oppsett',
    _text(band.sharedTech),
    '',
    'Personlige tekniske behov',
  ];
  final people = sortedRiderMembers(members);
  if (people.isEmpty) {
    lines.add('Ingen profiler er utfylt ennå.');
  } else {
    for (final member in people) {
      lines.add(_heading(member));
      lines.add('Personlig teknikk');
      lines.add(member.personalTech.trim().isEmpty ? 'Ikke utfylt' : member.personalTech.trim());
      lines.add('');
    }
  }
  return lines.join('\n').trimRight();
}

String formatRider(RiderKind kind, Band band, List<BandMember> members) {
  return switch (kind) {
    RiderKind.hospitality => formatHospitalityRider(band, members),
    RiderKind.technical => formatTechnicalRider(band, members),
  };
}

String _text(String value) => value.trim().isEmpty ? 'Ikke satt' : value.trim();

String _heading(BandMember member) {
  final name = member.name.trim().isEmpty ? 'Uten navn' : member.name.trim();
  final role = member.role.trim().isEmpty ? 'Rolle ikke satt' : member.role.trim();
  return '$name\n$role';
}
