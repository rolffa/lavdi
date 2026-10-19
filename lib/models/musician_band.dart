import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Band the signed-in musician belongs to (possibly several).
class MusicianBand {
  const MusicianBand({
    required this.bandId,
    required this.bandName,
    required this.artistId,
    required this.artistName,
    this.role = '',
    this.isActive = false,
  });

  final String bandId;
  final String bandName;
  final String artistId;
  final String artistName;
  final String role;
  final bool isActive;

  factory MusicianBand.fromJson(Map<String, dynamic> json) {
    return MusicianBand(
      bandId: json['band_id'] as String,
      bandName: (json['band_navn'] as String?)?.trim() ?? '',
      artistId: json['artist_id'] as String,
      artistName: (json['artist_navn'] as String?)?.trim() ?? '',
      role: (json['rolle'] as String?)?.trim() ?? '',
      isActive: json['er_aktiv'] as bool? ?? false,
    );
  }

  MusicianBand copyWith({bool? isActive}) {
    return MusicianBand(
      bandId: bandId,
      bandName: bandName,
      artistId: artistId,
      artistName: artistName,
      role: role,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// One band's mark on a calendar day (available or booked).
class CombinedCalendarMark {
  const CombinedCalendarMark({
    required this.date,
    required this.bandId,
    required this.bandName,
    required this.artistId,
    required this.isAvailable,
    required this.isBooked,
    this.gigId,
    this.gigTitle = '',
  });

  final DateTime date;
  final String bandId;
  final String bandName;
  final String artistId;
  final bool isAvailable;
  final bool isBooked;
  final String? gigId;
  final String gigTitle;

  factory CombinedCalendarMark.fromJson(Map<String, dynamic> json) {
    return CombinedCalendarMark(
      date: parseIsoDate(json['dato'] as String),
      bandId: json['band_id'] as String,
      bandName: (json['band_navn'] as String?)?.trim() ?? '',
      artistId: json['artist_id'] as String,
      isAvailable: json['er_tilgjengelig'] as bool? ?? false,
      isBooked: json['er_booket'] as bool? ?? false,
      gigId: json['gig_id'] as String?,
      gigTitle: (json['gig_tittel'] as String?)?.trim() ?? '',
    );
  }
}

/// Stable stamp color per band id (brand-adjacent, not purple defaults).
Color bandStampColor(String bandId) {
  const palette = <Color>[
    Color(0xFF1F5C4A),
    Color(0xFF8B4518),
    Color(0xFF2C4A6E),
    Color(0xFF6B4F1D),
    Color(0xFF4A5C2A),
    Color(0xFF7A3B3B),
    AppColors.ink,
  ];
  var hash = 0;
  for (final code in bandId.codeUnits) {
    hash = (hash + code * 31) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

String bandStampLabel(String bandName, {int max = 8}) {
  final trimmed = bandName.trim();
  if (trimmed.isEmpty) return 'Band';
  if (trimmed.length <= max) return trimmed;
  return '${trimmed.substring(0, max - 1)}…';
}
