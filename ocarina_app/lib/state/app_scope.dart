import 'package:flutter/widgets.dart';

import '../audio/sound_player.dart';
import 'progress_store.dart';

/// Makes the sound player and progress store available to the widget tree.
/// Widgets that read [progress] rebuild when it changes.
class AppScope extends InheritedNotifier<ProgressStore> {
  const AppScope({
    super.key,
    required ProgressStore progress,
    required this.player,
    required super.child,
  }) : super(notifier: progress);

  final SoundPlayer player;

  ProgressStore get progress => notifier!;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this context');
    return scope!;
  }
}
