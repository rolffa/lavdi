import 'dart:convert';
import 'dart:typed_data';

import 'package:amundsen_booking/core/input_list.dart';
import 'package:amundsen_booking/core/rider_export.dart';
import 'package:amundsen_booking/data/demo_catalog.dart';
import 'package:amundsen_booking/data/demo_portal_repository.dart';
import 'package:amundsen_booking/features/riders/rider_documents.dart';
import 'package:amundsen_booking/models/band.dart';
import 'package:amundsen_booking/models/stage_plot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('nb');
  });

  const band = Band(
    id: 'band',
    artistId: 'artist',
    name: 'Rolffa',
    contact: 'rolffa@lavdi.no',
    sharedTech: 'Stereomix til IEM.',
    sharedHospitality: '2 enkeltrom.',
    inputList: '4 linjer DI.',
    monitors: 'Ingen wedges.',
    stageRig: 'Ingen DJ.',
    paRequirements: 'Stereo PA.',
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
      name: '',
      role: 'Musiker',
      phone: '',
      food: '',
      personalTech: '',
    ),
  ];

  test('filenames and profile warnings follow the export', () {
    final day = DateTime(2026, 10, 12);
    expect(
      riderPdfFileName(RiderExport.complete, 'Rolffa', day),
      'Rider_Komplett_Rolffa_2026-10-12.pdf',
    );
    expect(
      riderPdfFileName(RiderExport.technical, 'R & GM', day),
      'Teknisk_Rider_R_&_GM_2026-10-12.pdf',
    );
    expect(
      riderPdfFileName(RiderExport.hospitality, '', day),
      'Hospitality_Rider_Band_2026-10-12.pdf',
    );

    final hospitality = riderProfileGaps(RiderExport.hospitality, members);
    expect(hospitality, hasLength(1));
    expect(hospitality.single.sentence, 'Uten navn mangler telefon, diett.');

    final technical = riderProfileGaps(RiderExport.technical, members);
    expect(technical.single.missing, ['telefon', 'personlig teknikk']);

    final complete = riderProfileGaps(RiderExport.complete, members);
    expect(complete.single.missing, ['telefon', 'diett', 'personlig teknikk']);
  });

  test('stage plot files are limited to png, jpg, svg and pdf', () {
    expect(
      () => checkedStagePlot(filename: 'kart.txt', bytes: Uint8List.fromList([1])),
      throwsA(isA<Exception>()),
    );
    expect(
      () => checkedStagePlot(filename: 'kart.png', bytes: Uint8List(stagePlotMaxBytes + 1)),
      throwsA(isA<Exception>()),
    );
    final plot = checkedStagePlot(
      filename: 'scene.SVG',
      bytes: Uint8List.fromList(utf8.encode('<svg/>')),
    );
    expect(plot.contentType, 'image/svg+xml');
    expect(plot.fileExtension, '.svg');
  });

  test('pdf riders include the band, diets and a stage plot page', () async {
    final when = DateTime(2026, 10, 12);
    final plot = StagePlot(
      name: 'scene.png',
      contentType: 'image/png',
      bytes: _png,
    );

    final technical = await TechnicalRiderDocument(
      band: band,
      members: members,
      stagePlot: plot,
      updatedAt: when,
    ).save(compress: false);
    final technicalText = latin1.decode(technical, allowInvalid: true);
    expect(technicalText, contains('(Teknisk)'));
    expect(technicalText, contains('(rider)'));
    expect(technicalText, contains('(Amundsen)'));
    expect(technicalText, contains('(INPUTLISTE)'));
    expect(technicalText, contains('(Scenekart)'));
    expect(technicalText, isNot(contains('kunne ikke tegnes')));
    expect(technicalText, isNot(contains('Vegetar')));

    final hospitality = await HospitalityRiderDocument(
      band: band,
      members: members,
      updatedAt: when,
    ).save(compress: false);
    final hospitalityText = latin1.decode(hospitality, allowInvalid: true);
    expect(hospitalityText, contains('(ROMFORDELING)'));
    expect(hospitalityText, contains('(enkeltrom.)'));
    expect(hospitalityText, contains('(Vegetar.)'));
    expect(hospitalityText, isNot(contains('(Scenekart)')));

    final svg = StagePlot(
      name: 'plot.svg',
      contentType: 'image/svg+xml',
      bytes: Uint8List.fromList(
        utf8.encode(
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="40"><rect width="80" height="40"/></svg>',
        ),
      ),
    );
    final combined = await CombinedRiderDocument(
      band: band,
      members: members,
      stagePlot: svg,
      updatedAt: when,
    ).save(compress: false);
    final combinedText = latin1.decode(combined, allowInvalid: true);
    expect(combinedText, contains('(Hospitality)'));
    expect(combinedText, contains('(Teknisk)'));
    expect(combinedText, contains('(Scenekart)'));
    expect(combinedText, contains('(oktober)'));

    final pdfPlot = StagePlot(
      name: 'kart.pdf',
      contentType: 'application/pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    final withPdf = await TechnicalRiderDocument(
      band: band,
      members: members,
      stagePlot: pdfPlot,
      updatedAt: when,
    ).save(compress: false);
    expect(
      latin1.decode(withPdf, allowInvalid: true),
      contains('(Originalen)'),
    );
  });

  test('the demo band stores a stage plot for the same calendar', () async {
    final repository = DemoPortalRepository(clock: () => DateTime(2026, 10, 12));
    await repository.signInArtist(
      email: DemoCatalog.artistEmail,
      password: DemoCatalog.artistPassword,
    );
    expect(await repository.fetchStagePlot(), isNull);

    final stored = await repository.uploadStagePlot(filename: 'scene.png', bytes: _png);
    expect(stored.name, 'scene.png');
    expect((await repository.fetchStagePlot())?.bytes, _png);
    expect((await repository.fetchMyBand())?.band.stagePlotName, 'scene.png');

    final technical = await repository.saveTechnicalRider(
      inputList: 'Ny patch.',
      monitors: 'IEM.',
      stageRig: '',
      paRequirements: 'PA.',
    );
    expect(technical.inputList, 'Ny patch.');
    expect(technical.stagePlotName, 'scene.png');

    await repository.clearStagePlot();
    expect(await repository.fetchStagePlot(), isNull);
    expect((await repository.fetchMyBand())?.band.stagePlotName, isEmpty);
  });

  test('the input list is a numbered table in both rider pdfs', () async {
    final patched = band.copyWith(
      inputList: encodeInputList(const [
        InputChannel(
          source: 'Kick',
          mic: 'Shure Beta 52',
          stand: 'Lavt m/ bom',
          notes: '48V',
        ),
        InputChannel(source: 'Snare', mic: 'SM57', stand: 'Lavt', notes: ''),
      ]),
    );
    final when = DateTime(2026, 10, 12);

    final technical = await TechnicalRiderDocument(
      band: patched,
      members: members,
      updatedAt: when,
    ).save(compress: false);
    final combined = await CombinedRiderDocument(
      band: patched,
      members: members,
      updatedAt: when,
    ).save(compress: false);

    for (final bytes in [technical, combined]) {
      final text = latin1.decode(bytes, allowInvalid: true);
      expect(text, contains('(INPUTLISTE)'));
      expect(text, contains('(Ch)'));
      expect(text, contains('(Source)'));
      expect(text, contains('(Instrument)'));
      expect(text, contains('(Mic)'));
      expect(text, contains('(Stand)'));
      expect(text, contains('(Notes)'));
      expect(text, contains('(48V)'));
      expect(text, contains('(Kick)'));
      expect(text, contains('(Shure)'));
      expect(text, contains('(Snare)'));
      expect(text, contains('(1)'));
      expect(text, contains('(2)'));
    }
  });
}

final _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
  0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83,
  222, 0, 0, 0, 12, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 0,
  0, 3, 1, 1, 0, 201, 254, 146, 239, 0, 0, 0, 0, 73, 69,
  78, 68, 174, 66, 96, 130,
]);
