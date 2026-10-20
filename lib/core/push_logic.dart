import '../models/band.dart';
import 'format.dart';

const bookingPushTitle = 'Ny bookingforespørsel!';
const travelBookPushTitle = 'Bestill reise';
const setlistPushTitle = 'Bekreft gårsdagens settliste';
const setlistPushBody =
    'Husket dere å bekrefte låtene fra konserten i går? Klikk for å godkjenne TONO-rapporten.';

bool isBandLeader({required bool isLeader, required String role}) {
  return isLeader || role.trim().toLowerCase() == 'bandleder';
}

/// Alle bandmedlemmer kan motta varsler i artistportalen.
bool receivesBandPush({required bool isLeader, required String role}) {
  return true;
}

/// E-postadresser for varsler: alle bandmedlemmer med aktiv konto.
List<String> bandMemberEmails(Iterable<({bool isLeader, String role, String email})> members) {
  final seen = <String>{};
  final emails = <String>[];
  for (final member in members) {
    final email = member.email.trim().toLowerCase();
    if (email.isEmpty || !seen.add(email)) continue;
    emails.add(email);
  }
  return emails;
}

/// @Deprecated Prefer [bandMemberEmails]. Beholdt for eldre kallsteder.
List<String> bandLeaderEmails(Iterable<({bool isLeader, String role, String email})> members) {
  return bandMemberEmails(members);
}

List<String> pushRecipientUserIds(Iterable<BandMember> members) {
  return [
    for (final member in members)
      if (member.userId != null &&
          member.userId!.isNotEmpty &&
          receivesBandPush(isLeader: member.isLeader, role: member.role))
        member.userId!,
  ];
}

String formatPushDate(DateTime date) {
  final day = dateOnly(date);
  final dayText = day.day.toString().padLeft(2, '0');
  final monthText = day.month.toString().padLeft(2, '0');
  return '$dayText.$monthText.${day.year}';
}

String bookingPushBody({
  required String organizer,
  required String venue,
  required DateTime date,
}) {
  final who = organizer.trim().isNotEmpty
      ? organizer.trim()
      : (venue.trim().isNotEmpty ? venue.trim() : 'En arrangør');
  return '$who har sendt en forespørsel for ${formatPushDate(date)}. Klikk for å se detaljer.';
}

String bookingPushUrl(String bookingId) => '/artist/foresporsler/$bookingId';

String travelBookPushBody({
  required String venue,
  required DateTime date,
}) {
  final where = venue.trim().isNotEmpty ? venue.trim() : 'konserten';
  return 'Arrangøren har fylt ut reiseinfo for $where (${formatPushDate(date)}). Bestill reise i artistportalen.';
}

String travelBookPushUrl(String gigId) => '/artist/gigs/$gigId';

String setlistPushUrl(String gigId) => '/artist/gigs/$gigId/settliste';
