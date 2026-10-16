import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin can hide and publish an artist page', () async {
    final repository = DemoPortalRepository();
    await repository.signInAdmin(
      username: DemoCatalog.adminUsername,
      password: DemoCatalog.adminPassword,
    );

    expect(
      (await repository.fetchArtists()).any((artist) => artist.id == DemoCatalog.linnId),
      isTrue,
    );
    expect(await repository.fetchArtist(DemoCatalog.linnId), isNotNull);
    expect(await repository.fetchPublicPressKit('rolffa'), isNotNull);

    await repository.setArtistPublished(
      artistId: DemoCatalog.linnId,
      published: false,
    );

    expect(
      (await repository.fetchArtists()).any((artist) => artist.id == DemoCatalog.linnId),
      isFalse,
    );
    expect(await repository.fetchArtist(DemoCatalog.linnId), isNull);
    expect(await repository.fetchPublicPressKit('rolffa'), isNull);

    final adminList = await repository.fetchAdminArtists();
    final hidden = adminList.singleWhere((artist) => artist.id == DemoCatalog.linnId);
    expect(hidden.published, isFalse);

    await repository.setArtistPublished(
      artistId: DemoCatalog.linnId,
      published: true,
    );
    expect(await repository.fetchArtist(DemoCatalog.linnId), isNotNull);
    expect(
      (await repository.fetchArtists()).any((artist) => artist.id == DemoCatalog.linnId),
      isTrue,
    );
  });
}
