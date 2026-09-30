import 'dart:async';

import 'package:flutter/material.dart';

import '../data/notes.dart';
import '../models/ocarina_note.dart';
import '../state/app_scope.dart';
import '../widgets/note_badge.dart';
import '../widgets/ocarina_diagram.dart';

/// Fingering chart: pick a note to see and hear it, or watch the whole
/// scale animate like a short video.
class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  OcarinaNote _selected = kNotes.first;
  Timer? _scaleTimer;

  bool get _playingScale => _scaleTimer != null;

  void _select(OcarinaNote note) {
    setState(() => _selected = note);
    AppScope.of(context).player.playNote(note);
  }

  void _toggleScale() {
    if (_playingScale) {
      _stopScale();
      return;
    }
    final player = AppScope.of(context).player;
    // Up the scale and back down, without repeating the top note.
    final sequence = [...kNotes, ...kNotes.reversed.skip(1)];
    var index = 0;
    void step() {
      final note = sequence[index];
      setState(() => _selected = note);
      player.playNote(note, duration: const Duration(milliseconds: 550));
      index++;
    }

    step();
    _scaleTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (index >= sequence.length) {
        _stopScale();
      } else {
        step();
      }
    });
    setState(() {});
  }

  void _stopScale() {
    _scaleTimer?.cancel();
    if (mounted) setState(() => _scaleTimer = null);
  }

  @override
  void dispose() {
    _scaleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return Scaffold(
      appBar: AppBar(title: const Text('Fingering chart')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NoteBadge(note: _selected),
          const SizedBox(height: 12),
          OcarinaDiagram(covered: _selected.covered),
          const SizedBox(height: 8),
          const DiagramLegend(),
          const SizedBox(height: 8),
          Text(
            '${_selected.frequency.toStringAsFixed(2)} Hz · '
            '${_selected.fingersDown} '
            '${_selected.fingersDown == 1 ? 'hole' : 'holes'} covered',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final note in kNotes)
                ChoiceChip(
                  label: Text(note.high ? "${note.letter}′" : note.letter),
                  selected: note == _selected,
                  onSelected: (_) => _select(note),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => player.playNote(
                  _selected,
                  duration: const Duration(milliseconds: 1500),
                ),
                icon: const Icon(Icons.volume_up),
                label: const Text('Hear it'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _toggleScale,
                icon: Icon(_playingScale ? Icons.stop : Icons.play_arrow),
                label: Text(_playingScale ? 'Stop' : 'Play the scale'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
