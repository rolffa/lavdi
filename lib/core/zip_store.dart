import 'dart:typed_data';

class ZipEntry {
  const ZipEntry({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Uint8List storeZip(List<ZipEntry> entries) {
  final locals = BytesBuilder(copy: false);
  final central = BytesBuilder(copy: false);
  var offset = 0;
  for (final entry in entries) {
    final name = Uint8List.fromList(entry.name.codeUnits);
    final crc = _crc32(entry.bytes);
    final local = BytesBuilder(copy: false);
    _u32(local, 0x04034b50);
    _u16(local, 20);
    _u16(local, 0);
    _u16(local, 0);
    _u16(local, 0);
    _u16(local, 0);
    _u32(local, crc);
    _u32(local, entry.bytes.length);
    _u32(local, entry.bytes.length);
    _u16(local, name.length);
    _u16(local, 0);
    local.add(name);
    local.add(entry.bytes);
    final localBytes = local.toBytes();
    locals.add(localBytes);

    _u32(central, 0x02014b50);
    _u16(central, 20);
    _u16(central, 20);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u32(central, crc);
    _u32(central, entry.bytes.length);
    _u32(central, entry.bytes.length);
    _u16(central, name.length);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u32(central, 0);
    _u32(central, offset);
    central.add(name);
    offset += localBytes.length;
  }

  final centralBytes = central.toBytes();
  final end = BytesBuilder(copy: false);
  _u32(end, 0x06054b50);
  _u16(end, 0);
  _u16(end, 0);
  _u16(end, entries.length);
  _u16(end, entries.length);
  _u32(end, centralBytes.length);
  _u32(end, offset);
  _u16(end, 0);

  final zip = BytesBuilder(copy: false);
  zip.add(locals.toBytes());
  zip.add(centralBytes);
  zip.add(end.toBytes());
  return zip.toBytes();
}

void _u16(BytesBuilder builder, int value) {
  builder.add([value & 0xff, (value >> 8) & 0xff]);
}

void _u32(BytesBuilder builder, int value) {
  builder.add([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
}

int _crc32(Uint8List bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      final mask = -(crc & 1);
      crc = (crc >> 1) ^ (0xedb88320 & mask);
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
