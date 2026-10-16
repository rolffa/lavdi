import 'package:amundsen_booking/core/rider_text.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/models/band.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('riders collect member profiles and keep the running order out', () {
    const band = Band(
      id: 'band',
      artistId: 'artist',
      name: 'Rolffa',
      contact: 'rolffa@lavdi.no',
      sharedTech: 'Stereomix til IEM.',
      sharedHospitality: '2 enkeltrom.',
    );
    const members = [
      BandMember(
        id: '1',
        bandId: 'band',
        name: 'Rolffa',
        role: 'Bandleder',
        phone: '900 10 010',
        food: 'Vegetar. Ingen nøtter.',
        personalTech: 'IEM, Shure PSM 300.',
        isLeader: true,
      ),
      BandMember(
        id: '2',
        bandId: 'band',
        name: 'Sigrid Holm',
        role: 'Musiker',
        phone: '900 20 020',
        food: 'Glutenfri.',
        personalTech: 'Trådløs gitar.',
      ),
    ];

    final hospitality = formatHospitalityRider(band, members);
    final technical = formatTechnicalRider(band, members);

    expect(hospitality, contains('Backstage og losji'));
    expect(hospitality, contains('2 enkeltrom.'));
    expect(hospitality, contains('Vegetar. Ingen nøtter.'));
    expect(hospitality, contains('Glutenfri.'));
    expect(hospitality, isNot(contains('Showstart')));
    expect(hospitality, isNot(contains('IEM')));

    expect(technical, contains('Felles teknisk oppsett'));
    expect(technical, contains('Stereomix til IEM.'));
    expect(technical, contains('Trådløs gitar.'));
    expect(technical, isNot(contains('Glutenfri')));
    expect(technical, isNot(contains('Get-in')));
  });

  test('an invite activates a member who must finish the profile', () async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 12));
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );

    final preview = await repository.previewInvite('demo-lyd');
    expect(preview?.email, 'lyd@lavdi.no');
    expect(preview?.role, 'Lydtekniker');

    final member = await repository.acceptInvite('demo-lyd');
    expect(member.profileComplete, isFalse);
    expect((await repository.fetchMyBand())!.me.profileComplete, isFalse);

    final saved = await repository.saveMyProfile(
      name: 'Mats Hauge',
      role: 'Lydtekniker',
      phone: '900 33 441',
      food: 'Ingen allergier.',
      personalTech: 'Ingen personlig IEM.',
    );
    expect(saved.profileComplete, isTrue);

    final riders = await repository.fetchRiders(DemoCatalog.productionToken);
    expect(riders, isNotNull);
    final text = formatTechnicalRider(riders!.band, riders.members);
    expect(text, contains('Mats Hauge\nLydtekniker'));
    expect(text, contains('Ingen personlig IEM.'));
    expect(text, contains('Stereomix til IEM.'));
  });
}
