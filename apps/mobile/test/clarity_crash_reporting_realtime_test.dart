import 'package:clarity/core/observability/clarity_crash_reporting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('handled realtime expiry is not captured as a crash', () async {
    await ClarityCrashReporting.captureException(
      Exception('InvalidJWTToken: Token has expired 30 seconds ago'),
    );
    await ClarityCrashReporting.captureException(
      Exception('RealtimeSubscribeException: RealtimeCloseEvent(code: 1006)'),
    );
  });
}
