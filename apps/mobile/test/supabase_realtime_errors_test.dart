import 'package:clarity/core/supabase/supabase_realtime_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies expired JWT from supabase_stream_builder', () {
    expect(
      isRecoverableSupabaseRealtimeError(
        Exception('InvalidJWTToken: Token has expired 84 seconds ago'),
      ),
      isTrue,
    );
  });

  test('classifies web realtime 1006 subscribe failure', () {
    expect(
      isRecoverableSupabaseRealtimeError(
        Exception(
          'RealtimeSubscribeException: RealtimeCloseEvent(code: 1006)',
        ),
      ),
      isTrue,
    );
  });

  test('does not treat unrelated errors as realtime expiry', () {
    expect(
      isRecoverableSupabaseRealtimeError(StateError('missing account')),
      isFalse,
    );
  });

  test('access token is stale at or after expiry minus skew', () {
    final now = DateTime.utc(2026, 8, 20, 12);
    final expiresAt = now.add(const Duration(minutes: 1)).millisecondsSinceEpoch ~/
        1000;
    expect(
      supabaseAccessTokenNeedsRefresh(expiresAt, now: now),
      isTrue,
    );
    expect(supabaseAccessTokenNeedsRefresh(null, now: now), isTrue);
    final later = now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    expect(
      supabaseAccessTokenNeedsRefresh(later, now: now),
      isFalse,
    );
  });
}
