import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/voice/data/voice_microphone_context.dart';

void main() {
  test('IO host reports microphone context as secure', () {
    expect(isVoiceMicrophoneContextSecure(), isTrue);
  });

  test('IO host does not treat microphone permission as permanently denied', () async {
    expect(await isWebMicrophonePermissionPermanentlyDenied(), isFalse);
  });
}
