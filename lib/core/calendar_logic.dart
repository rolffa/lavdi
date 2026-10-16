import 'format.dart';

const calendarWeekdays = ['man', 'tir', 'ons', 'tor', 'fre', 'lør', 'søn'];

List<DateTime?> monthCells(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final nextMonth = DateTime(month.year, month.month + 1, 1);
  final days = nextMonth.subtract(const Duration(days: 1)).day;
  final leading = first.weekday - DateTime.monday;
  return [
    ...List<DateTime?>.filled(leading, null),
    for (var day = 1; day <= days; day++) DateTime(month.year, month.month, day),
  ];
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool isPastDay(DateTime day, DateTime today) {
  return dateOnly(day).isBefore(dateOnly(today));
}

/// Friday and Saturday in the visible month, from [notBefore] onward.
List<DateTime> weekendDaysInMonth(DateTime month, {DateTime? notBefore}) {
  final earliest = notBefore == null ? null : dateOnly(notBefore);
  final days = <DateTime>[];
  for (final cell in monthCells(month)) {
    if (cell == null) continue;
    if (cell.weekday != DateTime.friday && cell.weekday != DateTime.saturday) continue;
    final day = dateOnly(cell);
    if (earliest != null && day.isBefore(earliest)) continue;
    days.add(day);
  }
  return days;
}

/// Organizers book more than a year ahead. Same horizon as the admin calendar.
const bookingHorizonMonths = 18;

bool canMoveMonth({
  required DateTime from,
  required int delta,
  required DateTime today,
}) {
  final target = DateTime(from.year, from.month + delta, 1);
  final earliest = DateTime(today.year, today.month, 1);
  final latest = DateTime(today.year, today.month + bookingHorizonMonths, 1);
  return !target.isBefore(earliest) && !target.isAfter(latest);
}

/// Same rule as the seed in `supabase/seed.sql`.
bool exampleDateIsAvailable(String artistName, DateTime date) {
  final seed = date.day + date.month + artistName.codeUnitAt(0);
  return seed % 5 != 0;
}
