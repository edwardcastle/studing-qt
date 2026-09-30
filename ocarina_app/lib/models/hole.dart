/// The twelve holes of a standard 12-hole transverse ocarina.
///
/// Finger holes are numbered from the mouthpiece outwards: `l1` is the left
/// index finger, `l4` the left pinky, and likewise for the right hand.
/// The thumb holes are on the underside of the instrument, and the two small
/// sub holes are only covered for the extra-low notes.
enum Hole {
  l1('L1', 'Left index'),
  l2('L2', 'Left middle'),
  l3('L3', 'Left ring'),
  l4('L4', 'Left pinky'),
  r1('R1', 'Right index'),
  r2('R2', 'Right middle'),
  r3('R3', 'Right ring'),
  r4('R4', 'Right pinky'),
  leftThumb('LT', 'Left thumb'),
  rightThumb('RT', 'Right thumb'),
  leftSub('LS', 'Left sub hole'),
  rightSub('RS', 'Right sub hole');

  const Hole(this.shortLabel, this.label);

  final String shortLabel;
  final String label;

  bool get isThumb => this == leftThumb || this == rightThumb;
  bool get isSub => this == leftSub || this == rightSub;
}

/// Every hole except the sub holes: the fingering for the lowest "main" note.
const Set<Hole> kMainHoles = {
  Hole.l1,
  Hole.l2,
  Hole.l3,
  Hole.l4,
  Hole.r1,
  Hole.r2,
  Hole.r3,
  Hole.r4,
  Hole.leftThumb,
  Hole.rightThumb,
};
