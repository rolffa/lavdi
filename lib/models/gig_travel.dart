class GigTravel {
  const GigTravel({
    required this.status,
    this.arrival,
    this.pickupLocation = '',
    this.departure,
    this.dropoffLocation = '',
  });

  static const notBooked = 'not_booked';
  static const booked = 'booked';

  final String status;
  final DateTime? arrival;
  final String pickupLocation;
  final DateTime? departure;
  final String dropoffLocation;

  bool get isBooked => status == booked;

  String get statusLabel => isBooked ? 'Reise bestilt' : 'Reise ikke bestilt ennå';

  const GigTravel.unbooked()
    : status = notBooked,
      arrival = null,
      pickupLocation = '',
      departure = null,
      dropoffLocation = '';

  factory GigTravel.fromJson(Map<String, dynamic> json) {
    return GigTravel(
      status: (json['travel_status'] as String?) ?? notBooked,
      arrival: _timestamp(json['arrival_time']),
      pickupLocation: (json['pickup_location'] as String?)?.trim() ?? '',
      departure: _timestamp(json['departure_time']),
      dropoffLocation: (json['dropoff_location'] as String?)?.trim() ?? '',
    );
  }

  static DateTime? _timestamp(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
