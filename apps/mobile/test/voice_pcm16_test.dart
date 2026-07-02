import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/voice/data/voice_pcm16.dart';

void main() {
  test('pcm16Decibels returns silence for empty chunks', () {
    expect(pcm16Decibels(Uint8List(0)), -160);
  });

  test('mergePcm16Chunks combines byte buffers', () {
    final merged = mergePcm16Chunks([
      Uint8List.fromList([1, 2]),
      Uint8List.fromList([3, 4, 5]),
    ]);

    expect(merged, Uint8List.fromList([1, 2, 3, 4, 5]));
  });

  test('boostPcm16Chunk amplifies samples without clipping', () {
    final chunk = Uint8List(4);
    final data = ByteData.sublistView(chunk);
    data.setInt16(0, 1000, Endian.little);
    data.setInt16(2, -1000, Endian.little);

    final boosted = boostPcm16Chunk(chunk, gain: 2.0);
    final boostedData = ByteData.sublistView(boosted);

    expect(boostedData.getInt16(0, Endian.little), 2000);
    expect(boostedData.getInt16(2, Endian.little), -2000);
  });
}
