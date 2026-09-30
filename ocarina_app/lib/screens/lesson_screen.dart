import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/notes.dart';
import '../data/songs.dart';
import '../models/hole.dart';
import '../models/lesson.dart';
import '../state/app_scope.dart';
import '../widgets/note_badge.dart';
import '../widgets/ocarina_diagram.dart';
import 'song_player_screen.dart';

/// Walks through a lesson's steps. Quiz steps must be answered correctly
/// before the learner can continue.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _index = 0;
  final Set<int> _solved = {};

  LessonStep get _step => widget.lesson.steps[_index];
  bool get _isLast => _index == widget.lesson.steps.length - 1;

  bool get _canContinue => switch (_step) {
    FingeringQuizStep() || EarQuizStep() => _solved.contains(_index),
    _ => true,
  };

  Future<void> _next() async {
    if (_isLast) {
      await AppScope.of(context).progress.completeLesson(widget.lesson.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lesson complete: ${widget.lesson.title}')),
      );
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
    }
  }

  void _markSolved() => setState(() => _solved.add(_index));

  @override
  Widget build(BuildContext context) {
    final steps = widget.lesson.steps;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_index + 1) / steps.length),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: switch (_step) {
                    InfoStep s => _InfoView(step: s),
                    NoteIntroStep s => _NoteIntroView(step: s),
                    FingeringQuizStep s => _FingeringQuizView(
                      step: s,
                      onSolved: _markSolved,
                    ),
                    EarQuizStep s => _EarQuizView(
                      step: s,
                      onSolved: _markSolved,
                    ),
                    SongStep s => _SongView(step: s),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_index > 0)
                    TextButton(
                      onPressed: () => setState(() => _index--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  Text('${_index + 1} / ${steps.length}'),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _canContinue ? _next : null,
                    child: Text(_isLast ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoView extends StatelessWidget {
  const _InfoView({required this.step});

  final InfoStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(step.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        OcarinaDiagram(covered: step.covered, highlight: step.highlight),
        const SizedBox(height: 16),
        Text(step.body, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _NoteIntroView extends StatelessWidget {
  const _NoteIntroView({required this.step});

  final NoteIntroStep step;

  @override
  Widget build(BuildContext context) {
    final note = noteById(step.noteId);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('New note', style: theme.textTheme.labelLarge),
        NoteBadge(note: note, size: 72),
        const SizedBox(height: 16),
        OcarinaDiagram(covered: note.covered),
        const SizedBox(height: 8),
        const DiagramLegend(),
        const SizedBox(height: 16),
        Text(step.tip, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonalIcon(
            onPressed: () => AppScope.of(context).player
                .playNote(note, duration: const Duration(milliseconds: 1500)),
            icon: const Icon(Icons.volume_up),
            label: const Text('Hear it'),
          ),
        ),
      ],
    );
  }
}

class _FingeringQuizView extends StatefulWidget {
  const _FingeringQuizView({required this.step, required this.onSolved});

  final FingeringQuizStep step;
  final VoidCallback onSolved;

  @override
  State<_FingeringQuizView> createState() => _FingeringQuizViewState();
}

class _FingeringQuizViewState extends State<_FingeringQuizView> {
  Set<Hole> _covered = {};
  bool _solved = false;
  bool _showHint = false;

  void _toggle(Hole hole) {
    if (_solved) return;
    setState(() {
      _covered = {..._covered};
      if (!_covered.remove(hole)) _covered.add(hole);
    });
    final target = noteById(widget.step.noteId);
    if (setEquals(_covered, target.covered)) {
      setState(() => _solved = true);
      AppScope.of(context).player.playNote(target);
      widget.onSolved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = noteById(widget.step.noteId);
    final theme = Theme.of(context);
    final wrong = {
      ..._covered.difference(target.covered),
      ...target.covered.difference(_covered),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your turn', style: theme.textTheme.labelLarge),
        Text(
          'Finger ${target.displayName}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the holes you would cover. Thumb holes are the dashed '
          'circles underneath.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        OcarinaDiagram(
          covered: _covered,
          highlight: _showHint && !_solved ? wrong : const {},
          onHoleTap: _toggle,
        ),
        const SizedBox(height: 16),
        if (_solved)
          Card(
            color: theme.colorScheme.primaryContainer,
            child: const ListTile(
              leading: Icon(Icons.celebration),
              title: Text('Correct!'),
              subtitle: Text('That is exactly the right fingering.'),
            ),
          )
        else
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showHint = !_showHint),
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(
                _showHint ? 'Hide hint' : 'Show which holes are wrong',
              ),
            ),
          ),
      ],
    );
  }
}

class _EarQuizView extends StatefulWidget {
  const _EarQuizView({required this.step, required this.onSolved});

  final EarQuizStep step;
  final VoidCallback onSolved;

  @override
  State<_EarQuizView> createState() => _EarQuizViewState();
}

class _EarQuizViewState extends State<_EarQuizView> {
  String? _picked;

  bool get _solved => _picked == widget.step.answerId;

  void _play() =>
      AppScope.of(context).player.playNote(noteById(widget.step.answerId));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ear training', style: theme.textTheme.labelLarge),
        Text('Which note is this?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: _play,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play the mystery note'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Compare with the options by long-pressing them.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final id in widget.step.optionIds)
              GestureDetector(
                onLongPress: () =>
                    AppScope.of(context).player.playNote(noteById(id)),
                child: ChoiceChip(
                  label: Text(noteById(id).displayName),
                  selected: _picked == id,
                  onSelected: _solved
                      ? null
                      : (_) {
                          setState(() => _picked = id);
                          if (_solved) widget.onSolved();
                        },
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_picked != null)
          Text(
            _solved ? 'Correct!' : 'Not quite. Listen again and try another.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _solved
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

class _SongView extends StatelessWidget {
  const _SongView({required this.step});

  final SongStep step;

  @override
  Widget build(BuildContext context) {
    final song = songById(step.songId);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.music_note, size: 64),
        Text(
          step.message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SongPlayerScreen(song: song),
              ),
            ),
            icon: const Icon(Icons.queue_music),
            label: Text('Open ${song.title}'),
          ),
        ),
      ],
    );
  }
}
