import 'dart:convert';

class InputChannel {
  const InputChannel({
    this.source = '',
    this.mic = '',
    this.stand = '',
    this.notes = '',
  });

  final String source;
  final String mic;
  final String stand;
  final String notes;

  bool get isEmpty =>
      source.trim().isEmpty && mic.trim().isEmpty && stand.trim().isEmpty && notes.trim().isEmpty;

  Map<String, String> toJson() => {
    'source': source.trim(),
    'mic': mic.trim(),
    'stand': stand.trim(),
    'notes': notes.trim(),
  };

  factory InputChannel.fromJson(Map<String, dynamic> json) {
    return InputChannel(
      source: (json['source'] as String?)?.trim() ?? '',
      mic: (json['mic'] as String?)?.trim() ?? '',
      stand: (json['stand'] as String?)?.trim() ?? '',
      notes: (json['notes'] as String?)?.trim() ?? '',
    );
  }
}

/// Stored in `bands.input_liste`. Empty means no channels.
/// Older free text is kept as the source on channel 1.
String encodeInputList(List<InputChannel> rows) {
  final kept = [for (final row in rows) row.toJson()];
  if (kept.every((row) => row.values.every((value) => value.isEmpty))) return '';
  return jsonEncode({'v': 1, 'rows': kept});
}

List<InputChannel> decodeInputList(String stored) {
  final raw = stored.trim();
  if (raw.isEmpty) return const [InputChannel()];
  if (raw.startsWith('{')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['rows'] is List) {
        final rows = [
          for (final item in decoded['rows'] as List)
            if (item is Map) InputChannel.fromJson(Map<String, dynamic>.from(item)),
        ];
        if (rows.isNotEmpty) return rows;
      }
    } catch (_) {}
  }
  return [InputChannel(source: raw)];
}

List<InputChannel> filledInputChannels(String stored) {
  return [for (final row in decodeInputList(stored)) if (!row.isEmpty) row];
}

String formatInputList(String stored) {
  final rows = filledInputChannels(stored);
  if (rows.isEmpty) return 'Ikke satt';
  final lines = <String>[];
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    lines.add('${index + 1}. ${row.source.isEmpty ? '—' : row.source}');
    if (row.mic.isNotEmpty) lines.add('   Mic / DI: ${row.mic}');
    if (row.stand.isNotEmpty) lines.add('   Stand: ${row.stand}');
    if (row.notes.isNotEmpty) lines.add('   Notes / 48V: ${row.notes}');
  }
  return lines.join('\n');
}
