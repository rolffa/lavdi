class RepertoireTrack {
  const RepertoireTrack({
    required this.id,
    required this.title,
    required this.duration,
  });

  final String id;
  final String title;
  final String duration;

  factory RepertoireTrack.fromJson(Map<String, dynamic> json) {
    return RepertoireTrack(
      id: json['id'] as String,
      title: (json['tittel'] as String?)?.trim() ?? '',
      duration: (json['spilletid'] as String?)?.trim() ?? '',
    );
  }
}

class SetlistTrack {
  const SetlistTrack({
    required this.title,
    required this.duration,
    this.repertoireId,
    this.extra = false,
  });

  final String title;
  final String duration;
  final String? repertoireId;
  final bool extra;

  factory SetlistTrack.fromJson(Map<String, dynamic> json) {
    return SetlistTrack(
      title: (json['tittel'] as String?)?.trim() ?? '',
      duration: (json['spilletid'] as String?)?.trim() ?? '',
      repertoireId: json['repertoire_id'] as String?,
      extra: json['ekstra'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tittel': title,
      'spilletid': duration,
      'repertoire_id': repertoireId,
      'ekstra': extra,
    };
  }
}

class ConcertSetlist {
  const ConcertSetlist({
    required this.gigId,
    required this.tracks,
    required this.confirmed,
    required this.tonoText,
  });

  final String gigId;
  final List<SetlistTrack> tracks;
  final bool confirmed;
  final String tonoText;

  factory ConcertSetlist.empty(String gigId) {
    return ConcertSetlist(
      gigId: gigId,
      tracks: const [],
      confirmed: false,
      tonoText: '',
    );
  }
}
