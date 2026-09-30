import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocarina_quest/audio/tone_synth.dart';

void main() {
  const synth = ToneSynth(sampleRate: 8000);

  test('produces the requested number of samples within range', () {
    final s = synth.samples(440, const Duration(milliseconds: 500));
    expect(s.length, 4000);
    expect(s.every((v) => v >= -1 && v <= 1), isTrue);
  });

  test('fades in and out so notes do not click', () {
    final s = synth.samples(440, const Duration(milliseconds: 500));
    expect(s.first.abs(), lessThan(0.01));
    expect(s.last.abs(), lessThan(0.01));
  });

  test('pitch is close to the requested frequency', () {
    // Count rising zero crossings over the steady middle section.
    final s = synth.samples(500, const Duration(seconds: 1));
    var crossings = 0;
    for (var i = 1000; i < 7000; i++) {
      if (s[i - 1] < 0 && s[i] >= 0) crossings++;
    }
    final measured = crossings / (6000 / 8000);
    expect(measured, closeTo(500, 10));
  });

  test('writes a valid WAV header', () {
    final wav = synth.wav(440, const Duration(milliseconds: 100));
    final data = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(data.getUint32(24, Endian.little), 8000);
    expect(data.getUint32(40, Endian.little), 800 * 2);
    expect(wav.length, 44 + 800 * 2);
  });
}
