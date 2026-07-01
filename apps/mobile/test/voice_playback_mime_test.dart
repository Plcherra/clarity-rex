import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/voice/data/voice_playback_mime.dart';

void main() {
  group('normalizeVoicePlaybackMimeType', () {
    test('maps common Rex TTS types to browser-safe values', () {
      expect(normalizeVoicePlaybackMimeType('audio/mpeg'), 'audio/mpeg');
      expect(normalizeVoicePlaybackMimeType('audio/mp3'), 'audio/mpeg');
      expect(
        normalizeVoicePlaybackMimeType('audio/mpeg; charset=binary'),
        'audio/mpeg',
      );
      expect(normalizeVoicePlaybackMimeType('audio/linear16'), 'audio/pcm');
    });

    test('defaults empty values to audio/mpeg', () {
      expect(normalizeVoicePlaybackMimeType(''), 'audio/mpeg');
      expect(normalizeVoicePlaybackMimeType('   '), 'audio/mpeg');
    });
  });

  group('voicePlaybackDataUri', () {
    test('builds audioplayers web compatible data URI', () {
      final uri = voicePlaybackDataUri(
        minimalMpegAudioFrameBytes(),
        'audio/mpeg',
      );

      expect(uri.startsWith('data:audio/mpeg;base64,'), isTrue);
    });
  });
}
