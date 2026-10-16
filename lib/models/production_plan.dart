import 'package:flutter/material.dart';

import '../core/format.dart';

class ProductionPlan {
  const ProductionPlan({
    this.eventName = '',
    this.accommodationName = '',
    this.accommodationAddress = '',
    this.nearestAirport = '',
    this.airportDistance = '',
    this.travelRoute = '',
    this.getIn,
    this.soundcheck,
    this.showGetIn,
    this.showStart,
    this.curfew,
    this.dinner,
    this.loadOut,
    this.dinnerAtAccommodation = true,
    this.dinnerVenueName = '',
    this.dinnerAddress = '',
    this.technicianName = '',
    this.technicianPhone = '',
    this.notes = '',
    this.callTime,
    this.daySheetReady = false,
  });

  final String eventName;
  final String accommodationName;
  final String accommodationAddress;
  final String nearestAirport;
  final String airportDistance;
  final String travelRoute;

  bool get travelBriefReady =>
      nearestAirport.trim().isNotEmpty && airportDistance.trim().isNotEmpty;
  final TimeOfDay? getIn;
  final TimeOfDay? soundcheck;
  final TimeOfDay? showGetIn;
  final TimeOfDay? showStart;
  final TimeOfDay? curfew;
  final TimeOfDay? dinner;
  final TimeOfDay? loadOut;
  final bool dinnerAtAccommodation;
  final String dinnerVenueName;
  final String dinnerAddress;
  final String technicianName;
  final String technicianPhone;
  final String notes;
  final TimeOfDay? callTime;
  final bool daySheetReady;

  factory ProductionPlan.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    String text(String key) => (data[key] as String?)?.trim() ?? '';
    return ProductionPlan(
      eventName: text('arrangementsnavn'),
      accommodationName: text('overnatting_navn'),
      accommodationAddress: text('overnatting_adresse'),
      nearestAirport: text('flyplass'),
      airportDistance: text('avstand'),
      travelRoute: text('reiserute'),
      getIn: parseClock(data['get_in']),
      soundcheck: parseClock(data['lydprove']),
      showGetIn: parseClock(data['get_in_show']),
      showStart: parseClock(data['showstart']),
      curfew: parseClock(data['curfew']),
      dinner: parseClock(data['middag']),
      loadOut: parseClock(data['load_out']),
      dinnerAtAccommodation: data['middag_pa_overnatting'] as bool? ?? true,
      dinnerVenueName: text('middag_sted'),
      dinnerAddress: text('middag_adresse'),
      technicianName: text('tekniker_navn'),
      technicianPhone: text('tekniker_telefon'),
      notes: text('merknader'),
      callTime: parseClock(data['oppmote']),
      daySheetReady: data.containsKey('dagskjema')
          ? data['dagskjema'] == true
          : text('overnatting_adresse').isNotEmpty,
    );
  }

  Map<String, dynamic> toJson() {
    String? clock(TimeOfDay? time) => time == null ? null : formatClock(time);
    return {
      'arrangementsnavn': eventName.trim(),
      'overnatting_navn': accommodationName.trim(),
      'overnatting_adresse': accommodationAddress.trim(),
      'flyplass': nearestAirport.trim(),
      'avstand': airportDistance.trim(),
      'reiserute': travelRoute.trim(),
      'get_in': clock(getIn),
      'lydprove': clock(soundcheck),
      'get_in_show': clock(showGetIn),
      'showstart': clock(showStart),
      'curfew': clock(curfew),
      'middag': clock(dinner),
      'load_out': clock(loadOut),
      'middag_pa_overnatting': dinnerAtAccommodation,
      'middag_sted': dinnerVenueName.trim(),
      'middag_adresse': dinnerAddress.trim(),
      'tekniker_navn': technicianName.trim(),
      'tekniker_telefon': technicianPhone.trim(),
      'merknader': notes.trim(),
      'oppmote': clock(callTime),
      'dagskjema': daySheetReady,
    };
  }

  ProductionPlan copyWith({
    String? nearestAirport,
    String? airportDistance,
    String? travelRoute,
    TimeOfDay? callTime,
    TimeOfDay? getIn,
    TimeOfDay? soundcheck,
    TimeOfDay? showStart,
    String? accommodationName,
    String? accommodationAddress,
    String? dinnerVenueName,
    String? notes,
    bool? daySheetReady,
  }) {
    return ProductionPlan(
      eventName: eventName,
      accommodationName: accommodationName ?? this.accommodationName,
      accommodationAddress: accommodationAddress ?? this.accommodationAddress,
      nearestAirport: nearestAirport ?? this.nearestAirport,
      airportDistance: airportDistance ?? this.airportDistance,
      travelRoute: travelRoute ?? this.travelRoute,
      getIn: getIn ?? this.getIn,
      soundcheck: soundcheck ?? this.soundcheck,
      showGetIn: showGetIn,
      showStart: showStart ?? this.showStart,
      curfew: curfew,
      dinner: dinner,
      loadOut: loadOut,
      dinnerAtAccommodation: dinnerAtAccommodation,
      dinnerVenueName: dinnerVenueName ?? this.dinnerVenueName,
      dinnerAddress: dinnerAddress,
      technicianName: technicianName,
      technicianPhone: technicianPhone,
      notes: notes ?? this.notes,
      callTime: callTime ?? this.callTime,
      daySheetReady: daySheetReady ?? this.daySheetReady,
    );
  }
}

class Organizer {
  const Organizer({
    required this.name,
    required this.organization,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.venueCity,
    this.notes = '',
  });

  final String name;
  final String organization;
  final String contactPerson;
  final String email;
  final String phone;
  final String venueCity;
  final String notes;

  factory Organizer.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    String text(String key) => (data[key] as String?)?.trim() ?? '';
    return Organizer(
      name: text('arrangor_navn'),
      organization: text('organisasjon'),
      contactPerson: text('kontaktperson'),
      email: text('epost'),
      phone: text('telefon'),
      venueCity: text('spillested'),
      notes: text('notater'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'arrangor_navn': name,
      'organisasjon': organization,
      'kontaktperson': contactPerson,
      'epost': email,
      'telefon': phone,
      'spillested': venueCity,
      'notater': notes,
    };
  }
}
