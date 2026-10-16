import '../models/booking_deal.dart';
import 'format.dart';

const offerReplyWindow = Duration(hours: 48);

DateTime offerReplyDeadline(DateTime sentAt) => sentAt.add(offerReplyWindow);

DateTime daySheetDue(DateTime concertDate) => addCalendarDays(dateOnly(concertDate), -30);

bool crewTravelComplete(Iterable<CrewLeg> legs) {
  final active = legs.where((leg) => leg.active).toList();
  if (active.isEmpty) return false;
  return active.every((leg) => leg.booked);
}

String replyWindowLabel(DateTime deadline, DateTime now) {
  final left = deadline.difference(now);
  if (!left.isNegative && left.inMinutes == 0 && left.inSeconds > 0) {
    return 'Under ett minutt igjen av 48 timer';
  }
  if (left.isNegative || left.inMinutes <= 0) return 'Svarfristen er ute';
  final hours = left.inHours;
  final minutes = left.inMinutes.remainder(60);
  if (hours >= 1) return '$hours t $minutes min igjen av 48 timer';
  return '${left.inMinutes} min igjen av 48 timer';
}
