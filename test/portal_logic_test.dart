import 'package:amundsen_booking/core/calendar_logic.dart';
import 'package:amundsen_booking/core/format.dart';
import 'package:amundsen_booking/core/spotify.dart';
import 'package:amundsen_booking/models/production_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('nb');
  });

  test('spotify uri becomes an embed url', () {
    expect(
      spotifyEmbedUrl('spotify:artist:1WgXqy2Dd70QQOU7Ay074N'),
      'https://open.spotify.com/embed/artist/1WgXqy2Dd70QQOU7Ay074N?utm_source=generator&theme=0',
    );
    expect(
      spotifyEmbedUrl('https://open.spotify.com/artist/1WgXqy2Dd70QQOU7Ay074N'),
      'https://open.spotify.com/embed/artist/1WgXqy2Dd70QQOU7Ay074N?utm_source=generator&theme=0',
    );
    expect(spotifyEmbedUrl(''), isNull);
  });

  test('october 2026 starts on thursday', () {
    final cells = monthCells(DateTime(2026, 10));
    expect(cells.take(3), everyElement(isNull));
    expect(cells[3], DateTime(2026, 10, 1));
    expect(cells.whereType<DateTime>().length, 31);
  });

  test('organizer calendar runs 18 months ahead', () {
    final today = DateTime(2026, 10, 11);
    expect(canMoveMonth(from: DateTime(2026, 10), delta: -1, today: today), isFalse);
    expect(canMoveMonth(from: DateTime(2026, 10), delta: 1, today: today), isTrue);
    expect(canMoveMonth(from: DateTime(2027, 2), delta: 1, today: today), isTrue);
    expect(canMoveMonth(from: DateTime(2028, 3), delta: 1, today: today), isTrue);
    expect(canMoveMonth(from: DateTime(2028, 4), delta: 1, today: today), isFalse);
  });

  test('availability rule matches the sql seed', () {
    expect(exampleDateIsAvailable('Linn Vold', DateTime(2026, 10, 12)), isTrue);
    expect(
      exampleDateIsAvailable('Linn Vold', DateTime(2026, 10, 12)),
      (12 + 10 + 'L'.codeUnitAt(0)) % 5 != 0,
    );
  });

  test('formats money and dates for the booking form', () {
    expect(formatNok(85000), '85\u00A0000 kr');
    expect(formatNok(999), '999 kr');
    expect(formatIsoDate(DateTime(2026, 10, 11)), '2026-10-11');
    expect(formatLongDate(DateTime(2026, 10, 11)), 'søndag 11. oktober 2026');
  });

  test('production plan keeps the mobile-app field names', () {
    const plan = ProductionPlan(
      eventName: 'Koengen',
      accommodationName: 'Hotel Norge',
      accommodationAddress: 'Nedre Ole Bulls plass',
      nearestAirport: 'BGO',
      travelRoute: 'Fly til BGO, bil 20 min',
      getIn: TimeOfDay(hour: 14, minute: 0),
      soundcheck: TimeOfDay(hour: 16, minute: 30),
      showGetIn: TimeOfDay(hour: 18, minute: 30),
      showStart: TimeOfDay(hour: 21, minute: 0),
      curfew: TimeOfDay(hour: 23, minute: 0),
      notes: 'Stille backstage',
    );

    final json = plan.toJson();
    expect(json['arrangementsnavn'], 'Koengen');
    expect(json['get_in'], '14:00');
    expect(json['lydprove'], '16:30');
    expect(json['get_in_show'], '18:30');
    expect(json['showstart'], '21:00');
    expect(json['curfew'], '23:00');
    expect(json['middag_pa_overnatting'], isTrue);
    expect(json['load_out'], isNull);

    final restored = ProductionPlan.fromJson(json);
    expect(restored.eventName, 'Koengen');
    expect(restored.soundcheck, const TimeOfDay(hour: 16, minute: 30));
    expect(restored.notes, 'Stille backstage');
  });
}
