import 'dart:io';
import 'dart:typed_data';

import 'package:amundsen_booking/core/artist_slug.dart';
import 'package:amundsen_booking/core/venue_match.dart';
import 'package:amundsen_booking/core/zip_store.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/models/venue_note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('artist slugs stay stable for the public press page', () {
    expect(artistSlug('EiGA'), 'eiga');
    expect(artistSlug('Felgen Orkester'), 'felgen-orkester');
    expect(artistSlug('Rolffa'), 'rolffa');
    expect(artistSlug('R & GM'), 'r-gm');
  });

  test('venue notes match the same place and stay hidden before the gig', () {
    final note = VenueNote(
      id: '1',
      bandId: 'band',
      venueName: 'Koengen',
      city: 'Bergen',
      loadInNotes: 'Heis',
      soundLightingNotes: '',
      hospitalityNotes: '',
      contactNotes: '',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    expect(venueNoteMatches(note, 'Koengen, Bergen'), isTrue);
    expect(venueNoteMatches(note, 'USF Verftet, Bergen'), isFalse);
    expect(splitVenueLabel('USF Verftet, Bergen'), (name: 'USF Verftet', city: 'Bergen'));
    expect(gigDayHasEnded(DateTime(2026, 10, 11), DateTime(2026, 10, 12)), isTrue);
    expect(gigDayHasEnded(DateTime(2026, 11, 2), DateTime(2026, 10, 12)), isFalse);
  });

  test('press zip lists every photo', () {
    final zip = storeZip([
      ZipEntry(name: 'presse-1.jpg', bytes: Uint8List.fromList([1, 2, 3])),
      ZipEntry(name: 'presse-2.png', bytes: Uint8List.fromList([9])),
    ]);
    final text = String.fromCharCodes(zip);
    expect(text, contains('presse-1.jpg'));
    expect(text, contains('presse-2.png'));
    final file = File('${Directory.systemTemp.path}/lavdi-press-test.zip');
    file.writeAsBytesSync(zip);
    final listing = Process.runSync('unzip', ['-l', file.path]);
    expect(listing.exitCode, 0);
    expect(listing.stdout, contains('presse-1.jpg'));
    expect(listing.stdout, contains('presse-2.png'));
    file.deleteSync();
  });

  test('band leader edits the press kit and the public page reads it', () async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 12));
    final beforeLogin = await repository.fetchPublicPressKit('rolffa');
    expect(beforeLogin?.bio, contains('offisielle biografien'));
    expect(beforeLogin?.spotifyUri, contains('spotify:artist:'));
    expect(beforeLogin?.filled, isEmpty);

    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.savePressBio('Ny offisiell bio.');
    await repository.savePressPhoto(
      slot: 2,
      filename: 'scene.png',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );
    final kit = await repository.fetchPublicPressKit('rolffa');
    expect(kit?.bio, 'Ny offisiell bio.');
    expect(kit?.filled.single.slot, 2);
    expect(await repository.downloadPressPhoto(kit!.filled.single), [1, 2, 3, 4]);
    expect(await repository.fetchPublicPressKit(DemoCatalog.linnId), isNotNull);
    expect(await repository.fetchPublicPressKit('finnes-ikke'), isNull);
  });

  test('venue notes from a finished gig show up on the next concert there', () async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 12));
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    await repository.addVenueNote(
      venueName: 'Koengen',
      city: 'Bergen',
      loadInNotes: 'Bæring fra baksiden. Heis til scenenivå.',
      soundLightingNotes: 'God PA. Teknisk ansvarlig kjenner IEM.',
      hospitalityNotes: 'Garderobe under scenen. Varm mat i backstage.',
      contactNotes: 'Ida møter i døren.',
    );
    final upcoming = await repository.fetchVenueNotes();
    expect(
      upcoming.where((note) => venueNoteMatches(note, 'Koengen, Bergen')).single.contactNotes,
      'Ida møter i døren.',
    );
    expect(upcoming.where((note) => venueNoteMatches(note, 'USF Verftet, Bergen')), isEmpty);

    await repository.addVenueNote(
      venueName: 'USF Verftet',
      city: 'Bergen',
      loadInNotes: 'Trapp fra gaten. Ingen heis.',
      soundLightingNotes: 'Lavt tak over scenen.',
      hospitalityNotes: 'Kaffe i foajeen.',
      contactNotes: 'Mats ved lydbordet.',
    );
    final again = await repository.fetchVenueNotes();
    final usf = again.where((note) => venueNoteMatches(note, 'USF Verftet, Bergen')).single;
    expect(usf.loadInNotes, 'Trapp fra gaten. Ingen heis.');
    expect(again.where((note) => venueNoteMatches(note, 'Koengen, Bergen')), isNotEmpty);
  });
}
