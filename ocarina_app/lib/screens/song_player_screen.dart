import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/hole.dart';
import '../models/song.dart';
import '../state/app_scope.dart';
import '../widgets/note_badge.dart';
import '../widgets/ocarina_diagram.dart';

enum PlayerMode { watch, practice }

/// Plays a song two ways:
///  * Watch: the app plays the melody while the diagram animates each
///    fingering, like a tutorial video.
///  * Practice: the learner sets each fingering on the diagram and the song
///    advances when it is right.
class SongPlayerScreen extends StatefulWidget {
  const SongPlayerScreen({super.key, required this.song});

  final Song song;

  @override
  State<SongPlayerScreen> createState() => _SongPlayerScreenState();
}

class _SongPlayerScreenState extends State<SongPlayerScreen> {
  static const double _chipExtent = 56;

  PlayerMode _mode = PlayerMode.watch;
  int _index = 0;
  Timer? _timer;
  double _tempo = 1.0;
  Set<Hole> _practiceCovered = {};
  bool _showTarget = true;
  final ScrollController _strip = ScrollController();

  List<SongNote> get _notes => widget.song.notes;
  SongNote get _current => _notes[_index];
  bool get _playing => _timer != null;

  Duration _beatsToDuration(double beats) => Duration(
    milliseconds: (beats * 60000 / (widget.song.bpm * _tempo)).round(),
  );

  void _setIndex(int index) {
    setState(() => _index = index);
    if (_strip.hasClients) {
      final target =
          (index * _chipExtent) -
          (_strip.position.viewportDimension / 2) +
          _chipExtent / 2;
      _strip.animateTo(
        target.clamp(0, _strip.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // --- Watch mode -----------------------------------------------------------

  void _togglePlay() => _playing ? _stop() : _play();

  void _play() {
    if (_index >= _notes.length - 1) _setIndex(0);
    _playCurrent();
  }

  void _playCurrent() {
    final note = _current;
    final length = _beatsToDuration(note.beats);
    if (note.note != null) {
      // Leave a small gap so repeated notes are distinct.
      AppScope.of(context).player.playNote(note.note!, duration: length * 0.9);
    }
    _timer = Timer(length, () {
      if (!mounted) return;
      if (_index >= _notes.length - 1) {
        _stop();
        return;
      }
      _setIndex(_index + 1);
      _playCurrent();
    });
    setState(() {});
  }

  void _stop() {
    _timer?.cancel();
    if (mounted) setState(() => _timer = null);
  }

  // --- Practice mode --------------------------------------------------------

  void _practiceToggle(Hole hole) {
    final target = _current.note;
    if (target == null) return;
    setState(() {
      _practiceCovered = {..._practiceCovered};
      if (!_practiceCovered.remove(hole)) _practiceCovered.add(hole);
    });
    if (setEquals(_practiceCovered, target.covered)) {
      AppScope.of(context).player.playNote(target);
      _advancePractice();
    }
  }

  void _advancePractice() {
    var next = _index + 1;
    while (next < _notes.length && _notes[next].isRest) {
      next++;
    }
    if (next >= _notes.length) {
      AppScope.of(context).progress.completeSong(widget.song.id);
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Song complete!'),
          content: Text(
            'You fingered every note of ${widget.song.title}. Now try it on '
            'your real ocarina.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nice'),
            ),
          ],
        ),
      );
      _setIndex(0);
    } else {
      _setIndex(next);
    }
  }

  void _setMode(PlayerMode mode) {
    _stop();
    setState(() {
      _mode = mode;
      _practiceCovered = {};
    });
    _setIndex(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _strip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = widget.song;
    final current = _current;
    final practice = _mode == PlayerMode.practice;
    return Scaffold(
      appBar: AppBar(title: Text(song.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<PlayerMode>(
            segments: const [
              ButtonSegment(
                value: PlayerMode.watch,
                icon: Icon(Icons.ondemand_video),
                label: Text('Watch & listen'),
              ),
              ButtonSegment(
                value: PlayerMode.practice,
                icon: Icon(Icons.touch_app),
                label: Text('Practice'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _setMode(s.first),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _chipExtent,
            child: ListView.builder(
              controller: _strip,
              scrollDirection: Axis.horizontal,
              itemExtent: _chipExtent,
              itemCount: _notes.length,
              itemBuilder: (context, i) {
                final n = _notes[i];
                final active = i == _index;
                final label = n.note == null
                    ? '·'
                    : '${n.note!.letter}${n.note!.high ? '′' : ''}';
                return Padding(
                  padding: const EdgeInsets.all(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: practice || _playing ? null : () => _setIndex(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: active
                            ? theme.colorScheme.primary
                            : i < _index
                            ? theme.colorScheme.secondaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: active ? theme.colorScheme.onPrimary : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          NoteBadge(note: current.note),
          const SizedBox(height: 12),
          if (practice)
            OcarinaDiagram(
              covered: _practiceCovered,
              highlight: _showTarget && current.note != null
                  ? current.note!.covered
                  : const {},
              onHoleTap: _practiceToggle,
            )
          else
            OcarinaDiagram(covered: current.note?.covered ?? const {}),
          const SizedBox(height: 8),
          const DiagramLegend(),
          const SizedBox(height: 16),
          if (practice) ...[
            Text(
              'Set the fingering for the highlighted note. When it is right '
              'you will hear it and move on.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            SwitchListTile(
              title: const Text('Glow the holes to cover'),
              value: _showTarget,
              onChanged: (v) => setState(() => _showTarget = v),
            ),
          ] else ...[
            Center(
              child: FilledButton.icon(
                onPressed: _togglePlay,
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                label: Text(_playing ? 'Pause' : 'Play'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.speed),
                Expanded(
                  child: Slider(
                    value: _tempo,
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                    label: '${(song.bpm * _tempo).round()} bpm',
                    onChanged: (v) => setState(() => _tempo = v),
                  ),
                ),
                Text('${(song.bpm * _tempo).round()} bpm'),
              ],
            ),
          ],
          if (song.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(song.description, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
