class AvailabilityDay {
  const AvailabilityDay({
    required this.date,
    required this.isAvailable,
    this.isBooked = false,
  });

  final DateTime date;

  /// Open for booking. Always false when [isBooked] is true.
  final bool isAvailable;

  /// Confirmed concert on this date.
  final bool isBooked;
}
