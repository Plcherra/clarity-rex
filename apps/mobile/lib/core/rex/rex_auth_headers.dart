import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_realtime_errors.dart';

typedef RexAccessTokenProvider = String? Function();

class RexAuthException implements Exception {
  const RexAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class RexAuthHeaders {
  const RexAuthHeaders({
    RexAccessTokenProvider? accessTokenProvider,
    Future<void> Function()? ensureFreshSession,
  }) : _accessTokenProvider = accessTokenProvider,
       _ensureFreshSession = ensureFreshSession;

  final RexAccessTokenProvider? _accessTokenProvider;
  final Future<void> Function()? _ensureFreshSession;

  /// Refreshes a stale Supabase JWT before a voice ticket (or similar) request.
  Future<void> prepareSession() async {
    if (_ensureFreshSession != null) {
      await _ensureFreshSession();
      return;
    }
    if (_accessTokenProvider != null) return;
    await _refreshDefaultSessionIfStale();
  }

  Map<String, String> headers([Map<String, String> baseHeaders = const {}]) {
    final token = _accessToken();
    return {...baseHeaders, 'Authorization': 'Bearer $token'};
  }

  String accessToken() => _accessToken();

  String _accessToken() {
    final token = (_accessTokenProvider ?? _currentSupabaseAccessToken)();
    if (token == null || token.trim().isEmpty) {
      throw const RexAuthException('Sign in again before using the assistant.');
    }
    return token.trim();
  }
}

String? _currentSupabaseAccessToken() {
  try {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  } on Object {
    return null;
  }
}

Future<void> _refreshDefaultSessionIfStale() async {
  try {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) return;
    if (!supabaseAccessTokenNeedsRefresh(session.expiresAt)) return;
    await auth.refreshSession();
  } on Object {
    return;
  }
}
