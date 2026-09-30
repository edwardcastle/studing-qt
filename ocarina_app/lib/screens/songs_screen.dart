import 'package:flutter/material.dart';

import '../data/songs.dart';
import '../models/song.dart';
import '../state/app_scope.dart';
import 'song_player_screen.dart';

class SongsScreen extends StatelessWidget {
  const SongsScreen({super.key});

  static String _difficultyLabel(Difficulty d) => switch (d) {
    Difficulty.beginner => 'Beginner',
    Difficulty.easy => 'Easy',
    Difficulty.intermediate => 'Intermediate',
  };

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return Scaffold(
      appBar: AppBar(title: const Text('Songs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final song in kSongs)
            Card(
              child: ListTile(
                leading: Icon(
                  progress.isSongPractised(song.id)
                      ? Icons.star
                      : Icons.star_border,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(song.title),
                subtitle: Text(
                  '${_difficultyLabel(song.difficulty)} · notes: '
                  '${song.noteRange.map((n) => n.high ? "${n.letter}′" : n.letter).join(' ')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SongPlayerScreen(song: song),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
