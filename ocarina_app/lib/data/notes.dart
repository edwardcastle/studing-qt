import 'package:flutter/foundation.dart';

import '../models/hole.dart';
import '../models/ocarina_note.dart';

/// Natural notes of a 12-hole alto C (AC) ocarina, from the lowest note with
/// the sub holes open up to the top of the range.
///
/// On a 12-hole ocarina each step up the scale lifts one more finger:
/// the right hand from pinky to index, then the left hand from pinky to
/// index, then the left thumb and finally the right thumb.
const List<OcarinaNote> kNotes = [
  OcarinaNote(
    id: 'C',
    letter: 'C',
    solfege: 'Do',
    frequency: 523.25,
    covered: kMainHoles,
  ),
  OcarinaNote(
    id: 'D',
    letter: 'D',
    solfege: 'Re',
    frequency: 587.33,
    covered: {
      Hole.l1, Hole.l2, Hole.l3, Hole.l4, //
      Hole.r1, Hole.r2, Hole.r3, //
      Hole.leftThumb, Hole.rightThumb,
    },
  ),
  OcarinaNote(
    id: 'E',
    letter: 'E',
    solfege: 'Mi',
    frequency: 659.25,
    covered: {
      Hole.l1, Hole.l2, Hole.l3, Hole.l4, //
      Hole.r1, Hole.r2, //
      Hole.leftThumb, Hole.rightThumb,
    },
  ),
  OcarinaNote(
    id: 'F',
    letter: 'F',
    solfege: 'Fa',
    frequency: 698.46,
    covered: {
      Hole.l1, Hole.l2, Hole.l3, Hole.l4, //
      Hole.r1, //
      Hole.leftThumb, Hole.rightThumb,
    },
  ),
  OcarinaNote(
    id: 'G',
    letter: 'G',
    solfege: 'Sol',
    frequency: 783.99,
    covered: {
      Hole.l1, Hole.l2, Hole.l3, Hole.l4, //
      Hole.leftThumb, Hole.rightThumb,
    },
  ),
  OcarinaNote(
    id: 'A',
    letter: 'A',
    solfege: 'La',
    frequency: 880.00,
    covered: {
      Hole.l1, Hole.l2, Hole.l3, //
      Hole.leftThumb, Hole.rightThumb,
    },
  ),
  OcarinaNote(
    id: 'B',
    letter: 'B',
    solfege: 'Si',
    frequency: 987.77,
    covered: {
      Hole.l1, Hole.l2, //
      Hole.leftThumb, Hole.rightThumb,
    },
  ),
  OcarinaNote(
    id: "C'",
    letter: 'C',
    solfege: 'Do',
    frequency: 1046.50,
    covered: {Hole.l1, Hole.leftThumb, Hole.rightThumb},
    high: true,
  ),
  OcarinaNote(
    id: "D'",
    letter: 'D',
    solfege: 'Re',
    frequency: 1174.66,
    covered: {Hole.leftThumb, Hole.rightThumb},
    high: true,
  ),
  OcarinaNote(
    id: "E'",
    letter: 'E',
    solfege: 'Mi',
    frequency: 1318.51,
    covered: {Hole.rightThumb},
    high: true,
  ),
  OcarinaNote(
    id: "F'",
    letter: 'F',
    solfege: 'Fa',
    frequency: 1396.91,
    covered: {},
    high: true,
  ),
];

final Map<String, OcarinaNote> _byId = {for (final n in kNotes) n.id: n};

/// Looks up a note by its [OcarinaNote.id]. Throws if the id is unknown.
OcarinaNote noteById(String id) {
  final note = _byId[id];
  if (note == null) throw ArgumentError.value(id, 'id', 'Unknown note');
  return note;
}

/// Returns the note produced by exactly this set of covered holes, or null if
/// the combination is not one of the standard fingerings.
OcarinaNote? noteForFingering(Set<Hole> covered) {
  for (final note in kNotes) {
    if (setEquals(note.covered, covered)) return note;
  }
  return null;
}
