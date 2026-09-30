import 'dart:math' as math;
import 'dart:typed_data';

/// Synthesizes a soft, ocarina-like tone and encodes it as a 16-bit mono WAV.
///
/// An ocarina is a vessel flute, so its sound is close to a pure sine wave.
/// We add a touch of second and third harmonic, a little breath noise, a
/// gentle attack/release so notes don't click, and a delayed vibrato.
class ToneSynth {
  const ToneSynth({this.sampleRate = 22050});

  final int sampleRate;

  /// Returns raw PCM samples in the range [-1, 1].
  Float64List samples(double frequency, Duration duration) {
    final count = (sampleRate * duration.inMicroseconds / 1e6).round();
    final out = Float64List(count);
    const attack = 0.04;
    const release = 0.08;
    const vibratoDelay = 0.18;
    final totalSeconds = count / sampleRate;
    // Tiny deterministic LCG so output is reproducible (and testable).
    var seed = 0x2545F491;
    var phase = 0.0;
    for (var i = 0; i < count; i++) {
      final t = i / sampleRate;
      final vibratoDepth = t < vibratoDelay ? 0.0 : 0.004;
      final f =
          frequency * (1 + vibratoDepth * math.sin(2 * math.pi * 5.2 * t));
      phase += 2 * math.pi * f / sampleRate;

      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final noise = (seed / 0x7fffffff) * 2 - 1;

      final tone =
          math.sin(phase) +
          0.08 * math.sin(2 * phase) +
          0.03 * math.sin(3 * phase) +
          0.02 * noise;

      var env = 1.0;
      if (t < attack) env = t / attack;
      final remaining = totalSeconds - t;
      if (remaining < release) env *= math.max(0, remaining / release);

      out[i] = 0.6 * env * tone;
    }
    return out;
  }

  /// Returns a complete WAV file for the tone.
  Uint8List wav(double frequency, Duration duration) =>
      encodeWav(samples(frequency, duration), sampleRate);
}

/// Encodes [samples] (range [-1, 1]) as a 16-bit PCM mono WAV file.
Uint8List encodeWav(Float64List samples, int sampleRate) {
  const bytesPerSample = 2;
  final dataSize = samples.length * bytesPerSample;
  final bytes = ByteData(44 + dataSize);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // fmt chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * bytesPerSample, Endian.little);
  bytes.setUint16(32, bytesPerSample, Endian.little);
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + i * bytesPerSample, v, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
