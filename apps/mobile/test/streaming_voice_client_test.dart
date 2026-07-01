import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/voice/data/streaming_voice_client.dart';

void main() {
  test('streamingVoiceClientTag distinguishes web from mobile', () {
    expect(streamingVoiceClientTag(isWeb: true), 'flutter_streaming_web');
    expect(streamingVoiceClientTag(isWeb: false), 'flutter_streaming');
  });
}
