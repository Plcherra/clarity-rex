import 'package:flutter/foundation.dart';

/// Supabase Auth redirect targets for email confirmation and password reset.
///
/// Native builds redirect to `https://goclarity.app/auth/confirmed/` so iOS
/// Universal Links / Android App Links open Clarity (not Chrome). Web builds
/// land in the Flutter PWA at `/app/`.
///
/// Shared `.env` web redirects must not override the native deep-link target.
///
/// Allow-list in Supabase Auth → Redirect URLs:
/// - `https://goclarity.app/auth/confirmed/`
/// - `https://goclarity.app/app/`
/// - `io.goclarity.clarity://login-callback` (browser fallback → app)
/// - `https://goclarity.app/auth/reset-password/`
class AuthConfig {
  static const String _emailRedirectOverride = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
  );

  static const String _passwordResetRedirectOverride = String.fromEnvironment(
    'SUPABASE_PASSWORD_RESET_REDIRECT_URL',
  );

  /// Custom scheme registered on iOS/Android (browser handoff fallback).
  static const String nativeCustomSchemeRedirectUrl =
      'io.goclarity.clarity://login-callback';

  /// HTTPS path claimed by Universal / App Links — opens Clarity when installed.
  static const String nativeEmailRedirectUrl =
      'https://goclarity.app/auth/confirmed/';

  /// Flutter web PWA — supabase_flutter reads `code` / tokens from the URL.
  static const String webEmailRedirectUrl = 'https://goclarity.app/app/';

  static const String passwordResetRedirectUrlDefault =
      'https://goclarity.app/auth/reset-password/';

  static String get emailRedirectUrl {
    final override = _emailRedirectOverride.trim();
    if (kIsWeb) {
      if (override.isNotEmpty) return override;
      return webEmailRedirectUrl;
    }
    // Native: never use a shared https://…/app/ web override from .env.
    if (override.isNotEmpty && _isNativeCapableRedirect(override)) {
      return override;
    }
    return nativeEmailRedirectUrl;
  }

  static String get passwordResetRedirectUrl {
    final override = _passwordResetRedirectOverride.trim();
    if (override.isNotEmpty) return override;
    return passwordResetRedirectUrlDefault;
  }

  static bool _isNativeCapableRedirect(String url) {
    final normalized = url.toLowerCase();
    if (normalized.startsWith('io.goclarity.clarity://')) return true;
    if (normalized.startsWith('https://goclarity.app/auth/confirmed')) {
      return true;
    }
    return false;
  }

  /// Primary Flutter web PWA origin (P6 deploy target, `/app/` path on root domain).
  static const String webAppOrigin = 'https://goclarity.app';

  /// Production path prefix when Flutter web is served under the marketing domain.
  static const String webAppPathPrefix = '/app';
}
