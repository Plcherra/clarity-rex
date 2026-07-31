import 'package:flutter/foundation.dart';

/// Supabase Auth redirect targets for email confirmation and password reset.
///
/// Native builds use a custom scheme so the confirmation link opens Clarity
/// (handled by supabase_flutter / app_links → session). Web builds land in the
/// Flutter PWA at `/app/` so the same browser finishes the auth session.
///
/// Allow-list in Supabase Auth → Redirect URLs:
/// - `io.goclarity.clarity://login-callback`
/// - `https://goclarity.app/app/`
/// - `https://goclarity.app/auth/confirmed/` (legacy handoff page)
/// - `https://goclarity.app/auth/reset-password/`
class AuthConfig {
  static const String _emailRedirectOverride = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
  );

  static const String _passwordResetRedirectOverride = String.fromEnvironment(
    'SUPABASE_PASSWORD_RESET_REDIRECT_URL',
  );

  /// Custom scheme + host registered on iOS/Android for auth callbacks.
  static const String nativeEmailRedirectUrl =
      'io.goclarity.clarity://login-callback';

  /// Flutter web PWA — supabase_flutter reads `code` / tokens from the URL.
  static const String webEmailRedirectUrl = 'https://goclarity.app/app/';

  static const String passwordResetRedirectUrlDefault =
      'https://goclarity.app/auth/reset-password/';

  static String get emailRedirectUrl {
    final override = _emailRedirectOverride.trim();
    if (override.isNotEmpty) return override;
    if (kIsWeb) return webEmailRedirectUrl;
    return nativeEmailRedirectUrl;
  }

  static String get passwordResetRedirectUrl {
    final override = _passwordResetRedirectOverride.trim();
    if (override.isNotEmpty) return override;
    return passwordResetRedirectUrlDefault;
  }

  /// Primary Flutter web PWA origin (P6 deploy target, `/app/` path on root domain).
  static const String webAppOrigin = 'https://goclarity.app';

  /// Production path prefix when Flutter web is served under the marketing domain.
  static const String webAppPathPrefix = '/app';
}
