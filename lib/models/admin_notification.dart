class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.kind,
    required this.message,
    required this.createdAt,
    this.artistId,
    this.inviteId,
  });

  final String id;
  final String kind;
  final String message;
  final DateTime createdAt;
  final String? artistId;
  final String? inviteId;

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    return AdminNotification(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? '',
      message: json['message'] as String? ?? '',
      artistId: json['artist_id'] as String?,
      inviteId: json['invite_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
