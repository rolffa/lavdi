import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/booking_deal.dart';
import 'deal_logic.dart';
import 'format.dart';

Future<List<int>> buildCrewTravelPdf({
  required String artistName,
  required DateTime date,
  required String venue,
  required String organizerName,
  required List<CrewLeg> crew,
}) async {
  final active = crew.where((leg) => leg.active).toList();
  final away = crew.where((leg) => !leg.active).toList();
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text(
          'Reise til $venue',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(artistName),
        pw.Text(formatLongDate(date)),
        pw.Text(organizerName),
        pw.SizedBox(height: 16),
        pw.Text(
          crewTravelComplete(crew)
              ? 'Alle som skal være med har bestilt reise.'
              : 'Ikke alle aktive medlemmer har huket av for reise bestilt.',
        ),
        pw.SizedBox(height: 16),
        for (final leg in active) ...[
          pw.Text(
            '${leg.name} · ${leg.role}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(_moment('Ankomst', leg.arrival, leg.pickup)),
          pw.Text(_moment('Avreise', leg.departure, leg.dropoff)),
          pw.SizedBox(height: 10),
        ],
        if (away.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Ikke med på denne konserten',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          for (final leg in away) pw.Text('${leg.name} · ${leg.role}'),
        ],
      ],
    ),
  );
  return document.save();
}

String _moment(String label, DateTime? time, String place) {
  final when = time == null
      ? 'tid ikke satt'
      : '${formatLongDate(time.toLocal())} kl. ${formatClock(TimeOfDay.fromDateTime(time.toLocal()))}';
  final where = place.trim().isEmpty ? 'sted ikke satt' : place.trim();
  return '$label: $when · $where';
}
