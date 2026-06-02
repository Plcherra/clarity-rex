import 'package:supabase_flutter/supabase_flutter.dart';

typedef RexAccessTokenProvider = String? Function();

class RexAuthException implements Exception {
  const RexAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class RexAuthHeaders {
  const RexAuthHeaders({RexAccessTokenProvider? accessTokenProvider})
    : _accessTokenProvider = accessTokenProvider;

  final RexAccessTokenProvider? _accessTokenProvider;

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
