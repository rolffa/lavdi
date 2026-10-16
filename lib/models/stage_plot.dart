import 'dart:typed_data';

import '../core/errors.dart';

const stagePlotMaxBytes = 8 * 1024 * 1024;

class StagePlot {
  const StagePlot({
    required this.name,
    required this.contentType,
    required this.bytes,
    this.path = '',
  });

  final String name;
  final String contentType;
  final Uint8List bytes;
  final String path;

  bool get isSvg => contentType == 'image/svg+xml';

  bool get isPdf => contentType == 'application/pdf';

  bool get isRaster => contentType == 'image/png' || contentType == 'image/jpeg';

  String get fileExtension => switch (contentType) {
    'image/png' => '.png',
    'image/jpeg' => '.jpg',
    'image/svg+xml' => '.svg',
    'application/pdf' => '.pdf',
    _ => '',
  };
}

class StagePlotUpload {
  const StagePlotUpload({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

String? stagePlotContentType(String filename) {
  final lower = filename.trim().toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return null;
}

StagePlot checkedStagePlot({required String filename, required Uint8List bytes}) {
  final name = filename.trim();
  final type = stagePlotContentType(name);
  if (type == null) {
    throw PortalException('Bruk PNG, JPG, SVG eller PDF.');
  }
  if (bytes.isEmpty) throw PortalException('Filen er tom.');
  if (bytes.length > stagePlotMaxBytes) {
    throw PortalException('Scenekartet kan ikke være større enn 8 MB.');
  }
  return StagePlot(name: name, contentType: type, bytes: bytes);
}
