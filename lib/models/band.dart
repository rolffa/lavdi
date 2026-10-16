class Band {
  const Band({
    required this.id,
    required this.artistId,
    required this.name,
    required this.contact,
    required this.sharedTech,
    required this.sharedHospitality,
    this.inputList = '',
    this.monitors = '',
    this.stageRig = '',
    this.paRequirements = '',
    this.stagePlotPath = '',
    this.stagePlotName = '',
    this.stagePlotType = '',
  });

  final String id;
  final String? artistId;
  final String name;
  final String contact;
  final String sharedTech;
  final String sharedHospitality;
  final String inputList;
  final String monitors;
  final String stageRig;
  final String paRequirements;
  final String stagePlotPath;
  final String stagePlotName;
  final String stagePlotType;

  factory Band.fromJson(Map<String, dynamic> json) {
    return Band(
      id: json['id'] as String,
      artistId: json['artist_id'] as String?,
      name: (json['navn'] as String?)?.trim() ?? '',
      contact: (json['kontaktinfo'] as String?)?.trim() ?? '',
      sharedTech: (json['tech_felles'] as String?)?.trim() ?? '',
      sharedHospitality: (json['hospitality_felles'] as String?)?.trim() ?? '',
      inputList: (json['input_liste'] as String?)?.trim() ?? '',
      monitors: (json['monitor'] as String?)?.trim() ?? '',
      stageRig: (json['scenerigg'] as String?)?.trim() ?? '',
      paRequirements: (json['pa_krav'] as String?)?.trim() ?? '',
      stagePlotPath: (json['stage_plot_path'] as String?)?.trim() ?? '',
      stagePlotName: (json['stage_plot_name'] as String?)?.trim() ?? '',
      stagePlotType: (json['stage_plot_type'] as String?)?.trim() ?? '',
    );
  }

  Band copyWith({
    String? name,
    String? contact,
    String? sharedTech,
    String? sharedHospitality,
    String? inputList,
    String? monitors,
    String? stageRig,
    String? paRequirements,
    String? stagePlotPath,
    String? stagePlotName,
    String? stagePlotType,
  }) {
    return Band(
      id: id,
      artistId: artistId,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      sharedTech: sharedTech ?? this.sharedTech,
      sharedHospitality: sharedHospitality ?? this.sharedHospitality,
      inputList: inputList ?? this.inputList,
      monitors: monitors ?? this.monitors,
      stageRig: stageRig ?? this.stageRig,
      paRequirements: paRequirements ?? this.paRequirements,
      stagePlotPath: stagePlotPath ?? this.stagePlotPath,
      stagePlotName: stagePlotName ?? this.stagePlotName,
      stagePlotType: stagePlotType ?? this.stagePlotType,
    );
  }
}

class BandMember {
  const BandMember({
    required this.id,
    required this.bandId,
    required this.name,
    required this.role,
    required this.phone,
    required this.food,
    required this.personalTech,
    this.userId,
    this.email = '',
    this.isLeader = false,
  });

  final String id;
  final String bandId;
  final String? userId;
  final String name;
  final String role;
  final String phone;
  final String food;
  final String personalTech;
  final String email;
  final bool isLeader;

  bool get profileComplete =>
      name.trim().isNotEmpty &&
      role.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      food.trim().isNotEmpty &&
      personalTech.trim().isNotEmpty;

  factory BandMember.fromJson(Map<String, dynamic> json) {
    return BandMember(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      userId: json['user_id'] as String?,
      name: (json['navn'] as String?)?.trim() ?? '',
      role: (json['rolle'] as String?)?.trim() ?? '',
      phone: (json['telefon'] as String?)?.trim() ?? '',
      food: (json['mat'] as String?)?.trim() ?? '',
      personalTech: (json['tech_personlig'] as String?)?.trim() ?? '',
      email: (json['epost'] as String?)?.trim() ?? '',
      isLeader: json['er_leder'] as bool? ?? false,
    );
  }

  BandMember copyWith({
    String? name,
    String? role,
    String? phone,
    String? food,
    String? personalTech,
    String? userId,
  }) {
    return BandMember(
      id: id,
      bandId: bandId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      food: food ?? this.food,
      personalTech: personalTech ?? this.personalTech,
      email: email,
      isLeader: isLeader,
    );
  }
}

class BandInvite {
  const BandInvite({
    required this.id,
    required this.bandId,
    required this.email,
    required this.role,
    required this.token,
    this.accepted = false,
  });

  final String id;
  final String bandId;
  final String email;
  final String role;
  final String token;
  final bool accepted;

  factory BandInvite.fromJson(Map<String, dynamic> json) {
    return BandInvite(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      email: (json['epost'] as String?)?.trim() ?? (json['email'] as String?)?.trim() ?? '',
      role: (json['rolle'] as String?)?.trim() ?? '',
      token: json['token'] as String,
      accepted: json['accepted_at'] != null || json['brukt'] == true,
    );
  }
}

class BandInvitePreview {
  const BandInvitePreview({
    required this.bandName,
    required this.email,
    required this.role,
    required this.used,
  });

  final String bandName;
  final String email;
  final String role;
  final bool used;

  factory BandInvitePreview.fromJson(Map<String, dynamic> json) {
    return BandInvitePreview(
      bandName: (json['band_navn'] as String?)?.trim() ?? '',
      email: (json['epost'] as String?)?.trim() ?? '',
      role: (json['rolle'] as String?)?.trim() ?? '',
      used: json['brukt'] as bool? ?? false,
    );
  }
}

class BandRoster {
  const BandRoster({required this.band, required this.members});

  final Band band;
  final List<BandMember> members;
}

class BandOverview {
  const BandOverview({
    required this.band,
    required this.me,
    required this.members,
    required this.invites,
  });

  final Band band;
  final BandMember me;
  final List<BandMember> members;
  final List<BandInvite> invites;
}
