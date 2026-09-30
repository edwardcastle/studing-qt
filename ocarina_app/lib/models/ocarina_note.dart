import 'hole.dart';

/// A note the ocarina can play, together with the fingering that produces it.
class OcarinaNote {
  const OcarinaNote({
    required this.id,
    required this.letter,
    required this.solfege,
    required this.frequency,
    required this.covered,
    this.high = false,
  });

  /// Stable identifier used in song notation, e.g. `C`, `G`, `D'`.
  final String id;

  /// Letter name without octave mark, e.g. `C`.
  final String letter;

  /// Fixed-do solfège name, e.g. `Do`.
  final String solfege;

  /// Sounding pitch in Hz for an alto C ocarina.
  final double frequency;

  /// Holes that must be covered. Every other hole is open.
  final Set<Hole> covered;

  /// Whether this is the upper-octave version of [letter].
  final bool high;

  String get displayName => high ? "high $letter" : letter;

  /// Number of fingers (including thumbs) that are down.
  int get fingersDown => covered.length;

  @override
  String toString() => 'OcarinaNote($id)';
}
