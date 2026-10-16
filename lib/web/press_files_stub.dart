import 'dart:typed_data';

import '../core/errors.dart';

Future<({String name, Uint8List bytes})?> pickPressPhoto() async {
  throw PortalException('Opplasting av pressebilder krever nettleseren.');
}
