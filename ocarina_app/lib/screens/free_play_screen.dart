import 'package:flutter/material.dart';

import '../data/notes.dart';
import '../models/hole.dart';
import '../state/app_scope.dart';
import '../widgets/note_badge.dart';
import '../widgets/ocarina_diagram.dart';

/// A virtual ocarina: tap holes to cover them and hear the note you'd get.
class FreePlayScreen extends StatefulWidget {
  const FreePlayScreen({super.key});

  @override
  State<FreePlayScreen> createState() => _FreePlayScreenState();
}

class _FreePlayScreenState extends State<FreePlayScreen> {
  Set<Hole> _covered = {...kMainHoles};
  bool _autoPlay = true;

  void _toggle(Hole hole) {
    setState(() {
      _covered = {..._covered};
      if (!_covered.remove(hole)) _covered.add(hole);
    });
    if (_autoPlay) _blow();
  }

  void _blow() {
    final note = noteForFingering(_covered);
    if (note != null) AppScope.of(context).player.playNote(note);
  }

  @override
  Widget build(BuildContext context) {
    final note = noteForFingering(_covered);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Free play'),
        actions: [
          IconButton(
            tooltip: 'Cover all',
            onPressed: () => setState(() => _covered = {...kMainHoles}),
            icon: const Icon(Icons.front_hand),
          ),
          IconButton(
            tooltip: 'Open all',
            onPressed: () => setState(() => _covered = {}),
            icon: const Icon(Icons.back_hand_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tap the holes to cover or uncover them. Try lifting fingers one '
            'at a time from the right pinky and listen to the scale climb.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          NoteBadge(note: note),
          const SizedBox(height: 12),
          OcarinaDiagram(covered: _covered, onHoleTap: _toggle),
          const SizedBox(height: 8),
          const DiagramLegend(),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: note == null ? null : _blow,
              icon: const Icon(Icons.air),
              label: const Text('Blow'),
            ),
          ),
          SwitchListTile(
            title: const Text('Play when a hole changes'),
            value: _autoPlay,
            onChanged: (v) => setState(() => _autoPlay = v),
          ),
        ],
      ),
    );
  }
}
