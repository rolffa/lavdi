import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<({String name, Uint8List bytes})?> pickPressPhoto() {
  final completer = Completer<({String name, Uint8List bytes})?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.png,.jpg,.jpeg,.webp,image/png,image/jpeg,image/webp';
  input.style.display = 'none';
  var settled = false;

  void finish(({String name, Uint8List bytes})? value) {
    if (settled) return;
    settled = true;
    input.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  input.addEventListener(
    'change',
    ((web.Event event) {
      final file = input.files?.item(0);
      if (file == null) {
        finish(null);
        return;
      }
      unawaited(() async {
        try {
          final buffer = await file.arrayBuffer().toDart;
          finish((name: file.name, bytes: buffer.toDart.asUint8List()));
        } catch (_) {
          finish(null);
        }
      }());
    }).toJS,
  );
  web.document.body?.append(input);
  input.click();
  return completer.future;
}
