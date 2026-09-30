import 'package:flutter/material.dart';

import 'app.dart';
import 'audio/sound_player.dart';
import 'state/progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = await ProgressStore.load();
  runApp(OcarinaQuestApp(progress: progress, player: SynthSoundPlayer()));
}
