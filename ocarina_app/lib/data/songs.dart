import '../models/song.dart';

/// Public-domain melodies arranged for the natural range of a 12-hole
/// alto C ocarina, ordered roughly by difficulty.
final List<Song> kSongs = [
  Song(
    id: 'hot_cross_buns',
    title: 'Hot Cross Buns',
    difficulty: Difficulty.beginner,
    bpm: 90,
    description: 'Only three notes: E, D and C. The perfect first tune.',
    notation:
        'E D C/2 | E D C/2 | '
        'C/0.5 C/0.5 C/0.5 C/0.5 D/0.5 D/0.5 D/0.5 D/0.5 | E D C/2',
  ),
  Song(
    id: 'mary_lamb',
    title: 'Mary Had a Little Lamb',
    difficulty: Difficulty.beginner,
    bpm: 100,
    description: 'Adds G to the right-hand notes you already know.',
    notation:
        'E D C D | E E E/2 | D D D/2 | E G G/2 | '
        'E D C D | E E E E | D D E D | C/4',
  ),
  Song(
    id: 'ode_to_joy',
    title: 'Ode to Joy',
    difficulty: Difficulty.easy,
    bpm: 100,
    description: 'Beethoven\'s famous theme moves step by step from C to G.',
    notation:
        'E E F G | G F E D | C C D E | E/1.5 D/0.5 D/2 | '
        'E E F G | G F E D | C C D E | D/1.5 C/0.5 C/2',
  ),
  Song(
    id: 'twinkle',
    title: 'Twinkle, Twinkle, Little Star',
    difficulty: Difficulty.easy,
    bpm: 100,
    description: 'Your first leap: C straight up to G, then up to A.',
    notation:
        'C C G G | A A G/2 | F F E E | D D C/2 | '
        'G G F F | E E D/2 | G G F F | E E D/2 | '
        'C C G G | A A G/2 | F F E E | D D C/2',
  ),
  Song(
    id: 'frere_jacques',
    title: 'Frère Jacques',
    difficulty: Difficulty.intermediate,
    bpm: 110,
    description: 'Played in G, it climbs into the high notes up to high E.',
    notation:
        'G A B G | G A B G | B C\' D\'/2 | B C\' D\'/2 | '
        'D\'/0.5 E\'/0.5 D\'/0.5 C\'/0.5 B G | '
        'D\'/0.5 E\'/0.5 D\'/0.5 C\'/0.5 B G | '
        'G D G/2 | G D G/2',
  ),
  Song(
    id: 'amazing_grace',
    title: 'Amazing Grace',
    difficulty: Difficulty.intermediate,
    bpm: 80,
    description: 'A slow hymn in 3/4 that reaches up to high C.',
    notation:
        'C | F/2 A/0.5 F/0.5 | A/2 G | F/2 D | C/2 C | '
        'F/2 A/0.5 F/0.5 | A/2 G | C\'/3 | '
        'A C\'/1.5 A/0.5 | C\'/0.5 A/0.5 F/2 | C D/1.5 F/0.5 | '
        'F/0.5 D/0.5 C/2 | C F/2 A/0.5 F/0.5 | A/2 G | F/3',
  ),
];

Song songById(String id) => kSongs.firstWhere((s) => s.id == id);
