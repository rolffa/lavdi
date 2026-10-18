import 'package:amundsen_booking/core/maps_links.dart';
import 'package:amundsen_booking/core/setlist_logic.dart';
import 'package:amundsen_booking/core/tono.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/models/repertoire.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_fixtures.dart';

void main() {
  final clock = DateTime(2026, 10, 11);

  test('play time and tono text stay reportable', () {
    expect(normalizePlayTime('3:45'), '03:45');
    expect(normalizePlayTime('03:45'), '03:45');
    expect(normalizePlayTime('3:70'), isNull);

    final text = formatTonoSetlist(const [
      SetlistTrack(title: 'Nordavind', duration: '03:45'),
      SetlistTrack(title: 'Ekstra', duration: '02:10', extra: true),
    ]);
    expect(text, '1. Nordavind (03:45)\n2. Ekstra (02:10)');
  });

  test('setlist is due the day after the concert', () {
    expect(
      gigNeedsSetlistReport(
        gigDate: DateTime(2026, 10, 10),
        today: clock,
        confirmed: false,
      ),
      isTrue,
    );
    expect(
      gigNeedsSetlistReport(
        gigDate: DateTime(2026, 10, 10),
        today: clock,
        confirmed: true,
      ),
      isFalse,
    );
  });

  test('maps links use the accommodation address', () {
    expect(
      mapsDirectionsUrl('Nedre Ole Bulls plass 4, Bergen'),
      'https://www.google.com/maps/dir/?api=1&destination=Nedre%20Ole%20Bulls%20plass%204%2C%20Bergen',
    );
    expect(
      mapsNearbyUrl(address: 'Bergen', place: 'apotek'),
      contains('apotek%20Bergen'),
    );
  });

  test('demo artist sees yesterdays concert until the setlist is saved', () async {
    final repository = DemoPortalRepository(clock: () => clock);
    expect(
      () => repository.signInArtist(email: 'feil@example.com', password: 'lavdi'),
      throwsA(isA<Exception>()),
    );

    final yesterdayGig = await seedConfirmedGig(
      repository,
      clock: () => clock,
      date: DateTime(2026, 10, 10),
      venue: 'USF Verftet, Bergen',
      organizer: 'USF Verftet',
    );
    await seedConfirmedGig(
      repository,
      clock: () => clock,
      date: DateTime(2026, 11, 1),
      venue: 'Koengen, Bergen',
      organizer: 'Bergensfestivalen',
    );

    final session = await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    expect(session.artistName, 'Rolffa');

    final gigs = await repository.fetchMyGigs();
    expect(gigs, hasLength(2));
    final yesterday = gigs.firstWhere((gig) => gig.date == DateTime(2026, 10, 10));
    expect(yesterday.id, yesterdayGig.gigId);

    final upcoming = gigs.firstWhere((gig) => gig.date == DateTime(2026, 11, 1));
    expect(upcoming.organizer.phone, '900 00 000');

    expect((await repository.fetchSetlist(yesterday.id)).confirmed, isFalse);

    final saved = await repository.saveSetlist(
      gigId: yesterday.id,
      tracks: const [
        SetlistTrack(
          title: 'Nordavind',
          duration: '03:45',
          repertoireId: 'rep-1',
        ),
      ],
    );
    expect(saved.confirmed, isTrue);
    expect(saved.tonoText, '1. Nordavind (03:45)');
    expect((await repository.fetchSetlist(yesterday.id)).confirmed, isTrue);

    final added = await repository.saveRepertoireTrack(
      title: 'Ny låt',
      duration: '2:05',
    );
    expect(added.duration, '02:05');
    expect(await repository.fetchRepertoire(), hasLength(1));
  });
}
