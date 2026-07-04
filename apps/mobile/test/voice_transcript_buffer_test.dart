import 'package:clarity/rex/voice/application/voice_transcript_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceTranscriptBuffer', () {
    test('shows latest partial while STT is correcting', () {
      final buffer = VoiceTranscriptBuffer();
      buffer.updatePartial('PO');
      expect(buffer.visible, 'PO');

      buffer.updatePartial('yo');
      expect(buffer.visible, 'yo');
    });

    test('final transcript replaces stale partial guess', () {
      final buffer = VoiceTranscriptBuffer();
      buffer.updatePartial('PO');
      buffer.appendFinal('yo');

      expect(buffer.visible, 'yo');
    });

    test('does not duplicate corrected phrase on final', () {
      final buffer = VoiceTranscriptBuffer();
      buffer.updatePartial('No. I mean, two');
      buffer.appendFinal('No. I mean, chill.');

      expect(buffer.visible, 'No. I mean, chill.');
      expect(buffer.visible.contains('two No. I mean'), isFalse);
    });

    test('accumulates distinct final segments in one utterance', () {
      final buffer = VoiceTranscriptBuffer();
      buffer.appendFinal('Hello');
      buffer.appendFinal('world');

      expect(buffer.visible, 'Hello world');
    });

    test('shows finalized and partial text together across phrases', () {
      final buffer = VoiceTranscriptBuffer();
      buffer.updatePartial('Hello there');
      expect(buffer.visible, 'Hello there');

      buffer.appendFinal('Hello there.');
      expect(buffer.visible, 'Hello there.');

      buffer.updatePartial('how are you');
      expect(buffer.visible, 'Hello there. how are you');
    });

    test('clear resets partial and final text', () {
      final buffer = VoiceTranscriptBuffer();
      buffer.updatePartial('listening');
      buffer.appendFinal('done');
      buffer.clear();

      expect(buffer.visible, isEmpty);
    });
  });
}
