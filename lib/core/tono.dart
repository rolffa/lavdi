import '../models/repertoire.dart';

final playTimePattern = RegExp(r'^(\d{1,2}):([0-5]\d)$');

String? normalizePlayTime(String value) {
  final match = playTimePattern.firstMatch(value.trim());
  if (match == null) return null;
  final minutes = int.parse(match.group(1)!);
  return '${minutes.toString().padLeft(2, '0')}:${match.group(2)}';
}

String formatTonoSetlist(List<SetlistTrack> tracks) {
  final lines = <String>[];
  for (var index = 0; index < tracks.length; index++) {
    final track = tracks[index];
    lines.add('${index + 1}. ${track.title} (${track.duration})');
  }
  return lines.join('\n');
}
