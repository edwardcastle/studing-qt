import 'package:flutter_test/flutter_test.dart';
import 'package:ocarina_quest/data/lessons.dart';
import 'package:ocarina_quest/data/notes.dart';
import 'package:ocarina_quest/data/songs.dart';
import 'package:ocarina_quest/models/lesson.dart';
import 'package:ocarina_quest/models/song.dart';

void main() {
  group('parseNotation', () {
    test('parses notes, lengths, rests and bar lines', () {
      final notes = parseNotation("E D C/2 | R/0.5 C'");
      expect(notes.map((n) => n.note?.id), ['E', 'D', 'C', null, "C'"]);
      expect(notes.map((n) => n.beats), [1, 1, 2, 0.5, 1]);
      expect(notes[3].isRest, isTrue);
    });

    test('rejects bad input', () {
      expect(() => parseNotation('X'), throwsArgumentError);
      expect(() => parseNotation('C/0'), throwsFormatException);
      expect(() => parseNotation('C/1/2'), throwsFormatException);
    });
  });

  test('every bundled song parses and has a unique id', () {
    expect(kSongs.map((s) => s.id).toSet(), hasLength(kSongs.length));
    for (final song in kSongs) {
      expect(song.notes, isNotEmpty, reason: song.id);
      expect(song.totalBeats, greaterThan(0));
    }
  });

  test('Hot Cross Buns only uses E, D and C', () {
    expect(songById('hot_cross_buns').noteRange.map((n) => n.id), [
      'C',
      'D',
      'E',
    ]);
  });

  test('lessons reference real notes and songs', () {
    expect(kLessons.map((l) => l.id).toSet(), hasLength(kLessons.length));
    for (final lesson in kLessons) {
      for (final step in lesson.steps) {
        switch (step) {
          case NoteIntroStep(:final noteId):
          case FingeringQuizStep(:final noteId):
            noteById(noteId);
          case EarQuizStep(:final answerId, :final optionIds):
            expect(optionIds, contains(answerId));
            optionIds.forEach(noteById);
          case SongStep(:final songId):
            songById(songId);
          case InfoStep():
            break;
        }
      }
    }
  });

  test('every note is taught by some lesson', () {
    final taught = {
      for (final lesson in kLessons)
        for (final step in lesson.steps)
          if (step is NoteIntroStep) step.noteId,
    };
    expect(taught, kNotes.map((n) => n.id).toSet());
  });
}
