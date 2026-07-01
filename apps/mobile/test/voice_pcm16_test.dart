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
}
