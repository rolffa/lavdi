import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../models/stage_plot.dart';

Future<StagePlotUpload?> pickStagePlotFile() {
  final completer = Completer<StagePlotUpload?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.png,.jpg,.jpeg,.svg,.pdf,image/png,image/jpeg,image/svg+xml,application/pdf';
  input.style.display = 'none';
  var settled = false;

  void finish(StagePlotUpload? value) {
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
          finish(StagePlotUpload(name: file.name, bytes: buffer.toDart.asUint8List()));
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

void saveBytes(Uint8List bytes, String filename, String mime) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
