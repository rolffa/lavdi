class BookingDraft {
  const BookingDraft({
    required this.artistId,
    required this.date,
    required this.organizerName,
    required this.organization,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.venueCity,
    required this.notes,
  });

  final String artistId;
  final DateTime date;
  final String organizerName;
  final String organization;
  final String contactPerson;
  final String email;
  final String phone;
  final String venueCity;
  final String notes;
}
