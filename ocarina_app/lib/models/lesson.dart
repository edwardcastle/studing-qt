import '../models/hole.dart';

/// One screen within a lesson.
sealed class LessonStep {
  const LessonStep();
}

/// Explanatory text, optionally with holes highlighted on the diagram.
class InfoStep extends LessonStep {
  const InfoStep({
    required this.title,
    required this.body,
    this.highlight = const {},
    this.covered = const {},
  });

  final String title;
  final String body;
  final Set<Hole> highlight;
  final Set<Hole> covered;
}

/// Introduces a new note: shows its fingering and lets the learner hear it.
class NoteIntroStep extends LessonStep {
  const NoteIntroStep({required this.noteId, required this.tip});

  final String noteId;
  final String tip;
}

/// The learner must reproduce a note's fingering on the diagram.
class FingeringQuizStep extends LessonStep {
  const FingeringQuizStep({required this.noteId});

  final String noteId;
}

/// A note is played; the learner picks which one it was.
class EarQuizStep extends LessonStep {
  const EarQuizStep({required this.answerId, required this.optionIds});

  final String answerId;
  final List<String> optionIds;
}

/// Suggests a song that uses the notes learned so far.
class SongStep extends LessonStep {
  const SongStep({required this.songId, required this.message});

  final String songId;
  final String message;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<LessonStep> steps;
}
