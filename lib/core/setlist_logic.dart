import 'calendar_logic.dart';
import 'format.dart';

bool gigNeedsSetlistReport({
  required DateTime gigDate,
  required DateTime today,
  required bool confirmed,
}) {
  return !confirmed && isSameDay(dateOnly(gigDate), addCalendarDays(today, -1));
}
