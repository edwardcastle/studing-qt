import 'package:flutter/material.dart';

import '../models/ocarina_note.dart';

/// A large display of a note name with its solfège underneath.
class NoteBadge extends StatelessWidget {
  const NoteBadge({super.key, required this.note, this.size = 56});

  final OcarinaNote? note;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = note;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          n == null ? '?' : '${n.letter}${n.high ? '′' : ''}',
          style: theme.textTheme.displayMedium?.copyWith(
            fontSize: size,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          n == null
              ? 'not a standard fingering'
              : '${n.displayName} · ${n.solfege}',
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}
