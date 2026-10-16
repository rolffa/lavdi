class VenueNote {
  const VenueNote({
    required this.id,
    required this.bandId,
    required this.venueName,
    required this.city,
    required this.loadInNotes,
    required this.soundLightingNotes,
    required this.hospitalityNotes,
    required this.contactNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bandId;
  final String venueName;
  final String city;
  final String loadInNotes;
  final String soundLightingNotes;
  final String hospitalityNotes;
  final String contactNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory VenueNote.fromJson(Map<String, dynamic> json) {
    return VenueNote(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      venueName: (json['venue_name'] as String?)?.trim() ?? '',
      city: (json['city'] as String?)?.trim() ?? '',
      loadInNotes: (json['load_in_notes'] as String?)?.trim() ?? '',
      soundLightingNotes: (json['sound_lighting_notes'] as String?)?.trim() ?? '',
      hospitalityNotes: (json['hospitality_notes'] as String?)?.trim() ?? '',
      contactNotes: (json['contact_notes'] as String?)?.trim() ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
