/// Recoverable Supabase Realtime failures: expired JWT and a dead socket.
///
/// PYTHON-3 is `InvalidJWTToken` from `supabase_stream_builder.dart`.
/// PYTHON-B is `RealtimeSubscribeException` / `RealtimeCloseEvent(code: 1006)`.
/// These must restart the watchers, not become a fatal zone crash.
bool isRecoverableSupabaseRealtimeError(Object error) {
  final type = error.runtimeType.toString().toLowerCase();
  final text = error.toString().toLowerCase();
  if (type.contains('invalidjwttoken') ||
      type.contains('realtimesubscribeexception') ||
      type.contains('realtimecloseevent')) {
    return true;
  }
  return text.contains('invalidjwttoken') ||
      text.contains('token has expired') ||
      text.contains('jwt expired') ||
      text.contains('realtimesubscribe') ||
      text.contains('realtimecloseevent') ||
      _hasAbnormalRealtimeClose(text);
}

bool _hasAbnormalRealtimeClose(String text) {
  return text.contains('code: 1006') ||
      text.contains('code=1006') ||
      text.contains('(1006)');
}

/// True when the access JWT is missing, already expired, or about to expire.
bool supabaseAccessTokenNeedsRefresh(
  int? expiresAtUnixSeconds, {
  DateTime? now,
  Duration skew = const Duration(minutes: 2),
}) {
  if (expiresAtUnixSeconds == null) return true;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(
    expiresAtUnixSeconds * 1000,
    isUtc: true,
  );
  final clock = (now ?? DateTime.now()).toUtc();
  return !clock.isBefore(expiresAt.subtract(skew));
}
