import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime addCalendarDays(DateTime date, int days) {
  final day = dateOnly(date);
  return DateTime(day.year, day.month, day.day + days);
}

String formatIsoDate(DateTime date) {
  final day = dateOnly(date);
  final year = day.year.toString().padLeft(4, '0');
  final month = day.month.toString().padLeft(2, '0');
  final dayOfMonth = day.day.toString().padLeft(2, '0');
  return '$year-$month-$dayOfMonth';
}

DateTime parseIsoDate(String value) {
  final parts = value.split('-');
  if (parts.length < 3) {
    throw FormatException('Ugyldig dato: $value');
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String formatLongDate(DateTime date) {
  return DateFormat('EEEE d. MMMM y', 'nb').format(dateOnly(date));
}

String formatMonth(DateTime date) {
  final label = DateFormat('MMMM y', 'nb').format(dateOnly(date));
  if (label.isEmpty) return label;
  return label[0].toUpperCase() + label.substring(1);
}

String formatNok(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('\u00A0');
    }
    buffer.write(digits[index]);
  }
  final sign = amount < 0 ? '-' : '';
  return '$sign$buffer kr';
}

String formatClock(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatDateTime(DateTime value) {
  return DateFormat('d. MMM y, HH:mm', 'nb').format(value.toLocal());
}

TimeOfDay? parseClock(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final parts = value.trim().split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}
