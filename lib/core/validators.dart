import 'package:flutter/material.dart';

String? requiredField(String? value, String message) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

String? emailField(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Oppgi e-post';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
    return 'Oppgi en gyldig e-post';
  }
  return null;
}

String? phoneField(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length < 8) return 'Oppgi telefonnummer';
  return null;
}

String? clockField(TimeOfDay? value, String message) {
  if (value == null) return message;
  return null;
}
