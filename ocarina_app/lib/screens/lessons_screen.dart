import 'package:flutter/material.dart';

import '../data/lessons.dart';
import '../state/app_scope.dart';
import 'lesson_screen.dart';

/// The learning path: lessons in order, with completion ticks.
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ocarina Quest'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => progress.reset(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset progress')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Your learning path', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${progress.lessonsDone} of ${kLessons.length} lessons complete',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.lessonsDone / kLessons.length,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          for (final (index, lesson) in kLessons.indexed)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: progress.isLessonDone(lesson.id)
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: progress.isLessonDone(lesson.id)
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  child: progress.isLessonDone(lesson.id)
                      ? const Icon(Icons.check)
                      : Text('${index + 1}'),
                ),
                title: Text(lesson.title),
                subtitle: Text(lesson.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LessonScreen(lesson: lesson),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
