class PushNotice {
  const PushNotice({
    required this.userId,
    required this.title,
    required this.body,
    required this.url,
    required this.dedupeKey,
  });

  final String userId;
  final String title;
  final String body;
  final String url;
  final String dedupeKey;
}
