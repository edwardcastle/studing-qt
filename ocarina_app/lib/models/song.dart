import '../data/notes.dart';
import 'ocarina_note.dart';

/// One event in a melody: a note (or a rest when [note] is null) and its
/// length in beats.
class SongNote {
  const SongNote(this.note, this.beats);

  final OcarinaNote? note;
  final double beats;

  bool get isRest => note == null;
}

enum Difficulty { beginner, easy, intermediate }

/// A melody the learner can listen to and practise.
class Song {
  Song({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.bpm,
    required String notation,
    this.description = '',
  }) : notes = parseNotation(notation);

  final String id;
  final String title;
  final Difficulty difficulty;
  final String description;

  /// Suggested tempo in beats per minute.
  final int bpm;
  final List<SongNote> notes;

  /// The distinct notes used, in scale order.
  List<OcarinaNote> get noteRange {
    final used = {
      for (final n in notes)
        if (n.note != null) n.note!.id,
    };
    return kNotes.where((n) => used.contains(n.id)).toList();
  }

  double get totalBeats => notes.fold(0, (sum, n) => sum + n.beats);
}

/// Parses compact melody notation.
///
/// Tokens are separated by whitespace. Each token is a note id from
/// [kNotes] (`C`, `D`, ... `C'`, `F'`) or `R` for a rest, optionally followed
/// by `/beats`. A token without a length lasts one beat.
///
/// Example: `E D C/2 R/1` is E and D for one beat each, C for two beats,
/// then a one-beat rest. A `|` token is a bar line and is ignored.
List<SongNote> parseNotation(String notation) {
  final result = <SongNote>[];
  for (final token in notation.split(RegExp(r'\s+'))) {
    if (token.isEmpty || token == '|') continue;
    final parts = token.split('/');
    if (parts.length > 2) throw FormatException('Bad token', token);
    final beats = parts.length == 2 ? double.parse(parts[1]) : 1.0;
    if (beats <= 0) throw FormatException('Beats must be positive', token);
    final id = parts[0];
    result.add(SongNote(id == 'R' ? null : noteById(id), beats));
  }
  return result;
}
