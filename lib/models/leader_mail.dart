class LeaderMail {
  const LeaderMail({
    required this.to,
    required this.subject,
    required this.body,
    required this.url,
    required this.dedupeKey,
  });

  final String to;
  final String subject;
  final String body;
  final String url;
  final String dedupeKey;
}
