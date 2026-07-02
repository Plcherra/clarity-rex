import 'dart:math';
import 'dart:typed_data';

double pcm16Decibels(Uint8List chunk) {
  if (chunk.length < 2) {
    return -160;
  }

  var sumSquares = 0.0;
  var sampleCount = 0;
  final byteData = ByteData.sublistView(chunk);
  for (var offset = 0; offset + 1 < chunk.length; offset += 2) {
    final sample = byteData.getInt16(offset, Endian.little) / 32768.0;
    sumSquares += sample * sample;
    sampleCount++;
  }
  if (sampleCount == 0 || sumSquares == 0) {
    return -160;
  }

  final rms = sqrt(sumSquares / sampleCount);
  return 20 * log(rms) / ln10;
}

/// Applies a modest gain boost for quiet browser mics without clipping.
Uint8List boostPcm16Chunk(Uint8List chunk, {double gain = 1.75}) {
  if (gain == 1.0 || chunk.length < 2) {
    return chunk;
  }

  final input = ByteData.sublistView(chunk);
  final output = Uint8List(chunk.length);
  final outData = ByteData.sublistView(output);
  for (var offset = 0; offset + 1 < chunk.length; offset += 2) {
    final sample = input.getInt16(offset, Endian.little);
    final boosted = (sample * gain).round().clamp(-32768, 32767);
    outData.setInt16(offset, boosted, Endian.little);
  }
  return output;
}

Uint8List mergePcm16Chunks(List<Uint8List> chunks) {
  if (chunks.isEmpty) {
    return Uint8List(0);
  }
  if (chunks.length == 1) {
    return Uint8List.fromList(chunks.single);
  }

  final totalLength = chunks.fold<int>(0, (total, chunk) => total + chunk.length);
  final merged = Uint8List(totalLength);
  var offset = 0;
  for (final chunk in chunks) {
    merged.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return merged;
}
