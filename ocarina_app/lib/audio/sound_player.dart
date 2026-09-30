import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../models/ocarina_note.dart';
import 'tone_synth.dart';

/// Plays ocarina notes. Abstracted so tests can run without audio.
abstract class SoundPlayer {
  Future<void> playNote(OcarinaNote note, {Duration duration});
  Future<void> stop();
  void dispose();
}

/// Default note length when tapping a note in the UI.
const Duration kTapNoteDuration = Duration(milliseconds: 900);

/// Plays synthesized notes through the platform audio backend.
class SynthSoundPlayer implements SoundPlayer {
  SynthSoundPlayer({this.synth = const ToneSynth()});

  final ToneSynth synth;
  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final Map<String, Uint8List> _cache = {};

  @override
  Future<void> playNote(
    OcarinaNote note, {
    Duration duration = kTapNoteDuration,
  }) async {
    final key = '${note.id}@${duration.inMilliseconds}';
    final wav = _cache.putIfAbsent(
      key,
      () => synth.wav(note.frequency, duration),
    );
    try {
      await _player.stop();
      await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {
      // Audio is a nice-to-have; never let a platform hiccup break a lesson.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  void dispose() => _player.dispose();
}

/// A player that makes no sound; used in tests.
class SilentSoundPlayer implements SoundPlayer {
  final List<String> played = [];

  @override
  Future<void> playNote(
    OcarinaNote note, {
    Duration duration = kTapNoteDuration,
  }) async => played.add(note.id);

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
