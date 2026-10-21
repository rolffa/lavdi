import 'dart:convert';
import 'dart:typed_data';

import '../models/booking_deal.dart';
import 'format.dart';

/// Bandsintown import-CSV for én bekreftet konsert.
/// Kolonneoverskrifter må matche Bandsintown sin mal eksakt.
Uint8List buildBandsintownCsvBytes(BookingDeal deal) {
  final csv = buildBandsintownCsv(deal);
  // UTF-8 med BOM slik at Excel/Numbers viser æøå og samiske tegn riktig.
  return Uint8List.fromList([...utf8.encode('\uFEFF'), ...utf8.encode(csv)]);
}

String buildBandsintownCsv(BookingDeal deal) {
  const headers =
      'Artist Name,Venue Name,City,State,Country,Start Date,Start Time,Ticket Link,Event Name,Description';

  final venueParts = _splitVenueCity(deal.venue);
  final startDate = _formatUsDate(deal.date);
  final startTime = deal.showStart == null ? '20:00' : formatClock(deal.showStart!);
  final eventName = '${deal.artistName} – ${venueParts.venue}'.trim();
  final description = deal.notes.trim().isNotEmpty
      ? deal.notes.trim()
      : deal.message.trim();

  final row = [
    deal.artistName.trim(),
    venueParts.venue,
    venueParts.city,
    '', // State – tom for norske byer
    'Norway',
    startDate,
    startTime,
    '', // Ticket Link
    eventName,
    description,
  ].map(_csvCell).join(',');

  return '$headers\r\n$row\r\n';
}

String bandsintownCsvFilename(BookingDeal deal) {
  final stamp = formatIsoDate(deal.date);
  final safe = deal.artistName
      .trim()
      .replaceAll(RegExp(r'[^\w\-æøåáčđŋšŧžÆØÅÁČĐŊŠŦŽ]+', unicode: true), '_');
  final name = safe.isEmpty ? 'artist' : safe;
  return 'bandsintown-$name-$stamp.csv';
}

String _formatUsDate(DateTime date) {
  final day = dateOnly(date);
  final month = day.month.toString().padLeft(2, '0');
  final dayOfMonth = day.day.toString().padLeft(2, '0');
  return '$month/$dayOfMonth/${day.year}';
}

({String venue, String city}) _splitVenueCity(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return (venue: '', city: '');
  final comma = value.lastIndexOf(',');
  if (comma > 0 && comma < value.length - 1) {
    final venue = value.substring(0, comma).trim();
    final city = value.substring(comma + 1).trim();
    if (venue.isNotEmpty && city.isNotEmpty) {
      return (venue: venue, city: city);
    }
  }
  // Én feltverdi (spillested/by) → bruk som både venue og city.
  return (venue: value, city: value);
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
