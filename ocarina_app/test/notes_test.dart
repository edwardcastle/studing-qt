import 'package:flutter_test/flutter_test.dart';
import 'package:ocarina_quest/data/notes.dart';
import 'package:ocarina_quest/models/hole.dart';

void main() {
  test('notes are ordered by rising pitch', () {
    for (var i = 1; i < kNotes.length; i++) {
      expect(kNotes[i].frequency, greaterThan(kNotes[i - 1].frequency));
    }
  });

  test('each step up lifts exactly one more finger', () {
    for (var i = 1; i < kNotes.length; i++) {
      final lower = kNotes[i - 1].covered;
      final upper = kNotes[i].covered;
      expect(lower.containsAll(upper), isTrue, reason: kNotes[i].id);
      expect(lower.length - upper.length, 1, reason: kNotes[i].id);
    }
  });

  test('fingerings are unique and never use the sub holes', () {
    final seen = <String>{};
    for (final note in kNotes) {
      final key = (note.covered.map((h) => h.index).toList()..sort()).join();
      expect(seen.add(key), isTrue, reason: note.id);
      expect(note.covered.any((h) => h.isSub), isFalse);
    }
  });

  test('noteForFingering is the inverse of the chart', () {
    for (final note in kNotes) {
      expect(noteForFingering({...note.covered}), same(note));
    }
    expect(noteForFingering({Hole.l1}), isNull);
    expect(noteForFingering({...kMainHoles, Hole.leftSub}), isNull);
  });

  test('octave notes are double the frequency', () {
    expect(noteById("C'").frequency, closeTo(noteById('C').frequency * 2, 0.1));
    expect(noteById("D'").frequency, closeTo(noteById('D').frequency * 2, 0.1));
  });

  test('noteById rejects unknown ids', () {
    expect(() => noteById('H'), throwsArgumentError);
  });
}
