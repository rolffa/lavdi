String mapsDirectionsUrl(String address) {
  return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address.trim())}';
}

String mapsNearbyUrl({required String address, required String place}) {
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$place ${address.trim()}')}';
}

const nearbyPlaces = <(String label, String query)>[
  ('Dagligvarebutikk', 'dagligvarebutikk'),
  ('Kafé', 'kafé'),
  ('Apotek', 'apotek'),
  ('Musikkforretning', 'musikkforretning'),
];
