import '../models/venue_note.dart';

({String name, String city}) splitVenueLabel(String venueCity) {
  final value = venueCity.trim();
  final comma = value.lastIndexOf(',');
  if (comma <= 0) return (name: value, city: '');
  return (
    name: value.substring(0, comma).trim(),
    city: value.substring(comma + 1).trim(),
  );
}

bool venueNoteMatches(VenueNote note, String venueCity) {
  final place = venueCity.trim().toLowerCase();
  final name = note.venueName.trim().toLowerCase();
  if (place.isEmpty || name.isEmpty) return false;
  if (place == name || place.startsWith('$name,')) return true;
  final city = note.city.trim().toLowerCase();
  if (city.isEmpty) return false;
  return place == '$name, $city';
}

bool gigDayHasEnded(DateTime gigDate, DateTime today) {
  final day = DateTime(gigDate.year, gigDate.month, gigDate.day);
  final current = DateTime(today.year, today.month, today.day);
  return !day.isAfter(current);
}
