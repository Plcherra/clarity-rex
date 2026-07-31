/// Supabase Auth redirect targets for email links opened in the browser.
///
/// Email confirmation lands on `/auth/confirmed/` which immediately forwards
/// into the Flutter PWA at `/app/` (preserving query/hash). Use the trailing
/// slash — Cloudflare serves `/auth/confirmed` as a 308 to the directory URL.
///
/// Password reset still uses `/auth/reset-password/` so the user can choose a
/// new password in the browser.
///
/// Allow-list in Supabase Auth redirect URLs:
/// - `https://goclarity.app/auth/confirmed`
/// - `https://goclarity.app/auth/confirmed/`
/// - `https://goclarity.app/app/`
/// - `https://goclarity.app/auth/reset-password`
/// - `https://goclarity.app/auth/reset-password/`
class AuthConfig {
  static const String emailRedirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
    defaultValue: 'https://goclarity.app/auth/confirmed/',
  );

  static const String passwordResetRedirectUrl = String.fromEnvironment(
    'SUPABASE_PASSWORD_RESET_REDIRECT_URL',
    defaultValue: 'https://goclarity.app/auth/reset-password/',
  );

  /// Primary Flutter web PWA origin (P6 deploy target, `/app/` path on root domain).
  static const String webAppOrigin = 'https://goclarity.app';

  /// Production path prefix when Flutter web is served under the marketing domain.
  static const String webAppPathPrefix = '/app';
}
