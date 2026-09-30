import '../models/hole.dart';
import '../models/lesson.dart';

const List<Lesson> kLessons = [
  Lesson(
    id: 'meet',
    title: 'Meet your ocarina',
    subtitle: 'Holes, grip and breath',
    steps: [
      InfoStep(
        title: 'The 12-hole ocarina',
        body:
            'This app teaches the 12-hole alto C ocarina, the most common '
            'kind for learners. The mouthpiece is on the left. Blow gently '
            'into it: the note depends on how many holes are covered, not on '
            'how hard you blow.',
      ),
      InfoStep(
        title: 'Left hand',
        body:
            'Your left hand sits nearest the mouthpiece. Index, middle, ring '
            'and pinky each cover one hole on top (L1–L4). The left thumb '
            'covers a hole underneath (LT).',
        highlight: {Hole.l1, Hole.l2, Hole.l3, Hole.l4, Hole.leftThumb},
      ),
      InfoStep(
        title: 'Right hand',
        body:
            'Your right hand covers R1–R4 on top and the right thumb hole '
            '(RT) underneath. Thumb holes are drawn with a dashed outline '
            'because you cannot see them while playing.',
        highlight: {Hole.r1, Hole.r2, Hole.r3, Hole.r4, Hole.rightThumb},
      ),
      InfoStep(
        title: 'Sub holes',
        body:
            'The two tiny sub holes (LS, RS) give extra-low notes. Leave '
            'them open for now; every note in these lessons plays with them '
            'uncovered.',
        highlight: {Hole.leftSub, Hole.rightSub},
      ),
      InfoStep(
        title: 'Cover the holes fully',
        body:
            'Use the flat pads of your fingers, not the tips. A hole that is '
            'only partly covered makes a squeaky, out-of-tune sound. Hold the '
            'ocarina lightly, balanced on your thumbs.',
        covered: kMainHoles,
      ),
      InfoStep(
        title: 'Breathe steadily',
        body:
            'Use a slow, warm, steady breath, like fogging a window. Start '
            'each note by whispering "doo" with your tongue. Low notes need '
            'less air; high notes need a little more.',
      ),
    ],
  ),
  Lesson(
    id: 'first_note',
    title: 'Your first note: C',
    subtitle: 'All ten main holes covered',
    steps: [
      NoteIntroStep(
        noteId: 'C',
        tip:
            'Cover all eight top holes and both thumb holes. This is the '
            'hardest note to seal well, so check each finger if it squeaks.',
      ),
      FingeringQuizStep(noteId: 'C'),
    ],
  ),
  Lesson(
    id: 'right_hand_1',
    title: 'D and E',
    subtitle: 'Lift the right pinky, then ring',
    steps: [
      NoteIntroStep(
        noteId: 'D',
        tip: 'From C, lift only your right pinky (R4).',
      ),
      NoteIntroStep(
        noteId: 'E',
        tip: 'From D, also lift your right ring finger (R3).',
      ),
      FingeringQuizStep(noteId: 'D'),
      FingeringQuizStep(noteId: 'E'),
      EarQuizStep(answerId: 'E', optionIds: ['C', 'D', 'E']),
      SongStep(
        songId: 'hot_cross_buns',
        message: 'You know enough to play Hot Cross Buns!',
      ),
    ],
  ),
  Lesson(
    id: 'right_hand_2',
    title: 'F and G',
    subtitle: 'Finish opening the right hand',
    steps: [
      NoteIntroStep(
        noteId: 'F',
        tip:
            'From E, lift your right middle finger (R2). Only the right '
            'index is still down on the right hand.',
      ),
      NoteIntroStep(
        noteId: 'G',
        tip:
            'Lift the right index too. All right-hand fingers are off the '
            'top; the right thumb stays underneath for balance.',
      ),
      FingeringQuizStep(noteId: 'F'),
      FingeringQuizStep(noteId: 'G'),
      EarQuizStep(answerId: 'C', optionIds: ['C', 'E', 'G']),
      SongStep(
        songId: 'ode_to_joy',
        message: 'C to G is enough for Ode to Joy and Mary Had a Little Lamb.',
      ),
    ],
  ),
  Lesson(
    id: 'left_hand',
    title: 'A, B and high C',
    subtitle: 'Now the left hand opens',
    steps: [
      NoteIntroStep(noteId: 'A', tip: 'From G, lift your left pinky (L4).'),
      NoteIntroStep(
        noteId: 'B',
        tip: 'From A, lift your left ring finger (L3).',
      ),
      NoteIntroStep(
        noteId: "C'",
        tip:
            'From B, lift your left middle finger (L2). Only the left index '
            'and both thumbs remain.',
      ),
      FingeringQuizStep(noteId: 'A'),
      FingeringQuizStep(noteId: 'B'),
      FingeringQuizStep(noteId: "C'"),
      EarQuizStep(answerId: 'A', optionIds: ['G', 'A', "C'"]),
      SongStep(
        songId: 'twinkle',
        message: 'Twinkle, Twinkle uses C through A.',
      ),
    ],
  ),
  Lesson(
    id: 'high_notes',
    title: 'The high notes',
    subtitle: 'High D, E and F with the thumbs',
    steps: [
      NoteIntroStep(
        noteId: "D'",
        tip:
            'Lift the left index. Only the two thumbs cover holes. Blow a '
            'little faster.',
      ),
      NoteIntroStep(
        noteId: "E'",
        tip:
            'Lift your left thumb as well. Hold the ocarina steady with the '
            'right thumb and your fingers resting on the body.',
      ),
      NoteIntroStep(
        noteId: "F'",
        tip:
            'Everything open! This is the highest natural note. Support the '
            'ocarina with your fingertips beside the holes.',
      ),
      FingeringQuizStep(noteId: "D'"),
      FingeringQuizStep(noteId: "E'"),
      FingeringQuizStep(noteId: "F'"),
      EarQuizStep(answerId: "F'", optionIds: ["C'", "D'", "F'"]),
      SongStep(
        songId: 'frere_jacques',
        message: 'Frère Jacques in G reaches all the way up to high E.',
      ),
    ],
  ),
];
