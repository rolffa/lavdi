import 'package:amundsen_booking/core/input_list.dart';
import 'package:amundsen_booking/features/riders/input_list_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy patch text stays one channel and empty text stays unset', () {
    final legacy = decodeInputList('Vokal 1, vokal 2, gitar og keys. 4 linjer DI.');
    expect(legacy, hasLength(1));
    expect(legacy.single.source, contains('4 linjer DI.'));
    expect(formatInputList(''), 'Ikke satt');
    expect(encodeInputList(const [InputChannel()]), isEmpty);

    final stored = encodeInputList(const [
      InputChannel(source: 'Kick', mic: 'Beta 52'),
      InputChannel(),
    ]);
    final decoded = decodeInputList(stored);
    expect(decoded, hasLength(2));
    expect(decoded.first.source, 'Kick');
    expect(decoded.last.isEmpty, isTrue);
    expect(formatInputList(stored), contains('1. Kick'));
    expect(formatInputList(stored), contains('Mic / DI: Beta 52'));
  });

  testWidgets('enter adds the next channel and delete renumbers', (tester) async {
    final controller = TextEditingController();
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InputListEditor(controller: controller, enabled: true)),
      ),
    );

    expect(find.text('Kanal 1'), findsOneWidget);
    expect(find.text('Kanal 2'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'Kick');
    await tester.enterText(find.byType(TextField).at(1), 'Shure Beta 52');
    await tester.enterText(find.byType(TextField).at(3), '48V');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Kanal 2'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).at(4)).focusNode!.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField).at(4), 'Snare');
    await tester.pump();
    await tester.tap(find.byTooltip('Slett kanal 1'));
    await tester.pump();

    expect(find.text('Kanal 2'), findsNothing);
    expect(find.text('Kanal 1'), findsOneWidget);
    expect(find.text('Snare'), findsOneWidget);
    expect(find.text('Kick'), findsNothing);

    final rows = decodeInputList(controller.text);
    expect(rows, hasLength(1));
    expect(rows.single.source, 'Snare');
  });
}
