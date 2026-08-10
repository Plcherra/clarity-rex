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

    test('preferFullest merges last segment with earlier segments', () {
      final merged = VoiceTranscriptBuffer.preferFullest([
        'so I can exercise at home.',
        'Everything good? I also want some weights so I can exercise at home.',
        'Everything good? I also want some weights',
      ]);

      expect(
        merged,
        'Everything good? I also want some weights so I can exercise at home.',
      );
    });

    test('stripLeadingUtterance removes sticky prior turn prefix', () {
      const prior =
          'OK so I am about to buy my first bike when I got my learning permit';
      const next =
          'OK so I am about to buy my first bike when I got my learning permit '
          'and I know it is possible with the CBR 600';

      expect(
        VoiceTranscriptBuffer.stripLeadingUtterance(
          next,
          priorUtterance: prior,
        ),
        'and I know it is possible with the CBR 600',
      );
    });

    test('stripLeadingUtterance keeps unrelated new speech', () {
      expect(
        VoiceTranscriptBuffer.stripLeadingUtterance(
          'and I know it is possible',
          priorUtterance: 'OK so I am about to buy my first bike',
        ),
        'and I know it is possible',
      );
    });

    test('stripLeadingUtterance tolerates small STT drift in the prefix', () {
      const prior =
          'Oh once I got my permit and that is the one that I am looking for '
          'and I am already have a biking mind';
      const next =
          'Oh once I got my permit and that is the one that I am looking for '
          'and I am already have a biking mine on a dealership yeah';

      expect(
        VoiceTranscriptBuffer.stripLeadingUtterance(
          next,
          priorUtterance: prior,
        ),
        'on a dealership yeah',
      );
    });
  });
}
