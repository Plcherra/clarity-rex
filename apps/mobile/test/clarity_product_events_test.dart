import 'package:clarity/core/observability/clarity_product_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product events accept metadata without throwing', () {
    ClarityProductEvents.writeConfirmationResult(
      result: 'failed',
      actionType: 'save_memory',
    );
    ClarityProductEvents.voiceStreamError(
      code: 'transcription_failed',
      statusCode: 502,
    );
    ClarityProductEvents.api5xx(statusCode: 500, path: '/chat');
  });
}
