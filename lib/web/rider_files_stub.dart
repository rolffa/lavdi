import 'dart:typed_data';

import '../core/errors.dart';
import '../models/stage_plot.dart';

Future<StagePlotUpload?> pickStagePlotFile() async {
  throw PortalException('Opplasting av scenekart krever nettleseren.');
}

void saveBytes(Uint8List bytes, String filename, String mime) {
  throw PortalException('PDF-nedlasting krever nettleseren.');
}
