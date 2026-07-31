/// Supabase Auth redirect targets for email links opened in the browser.
///
/// Production Flutter web lives at `/app/` on the root domain. Add
/// `https://goclarity.app` (and `/app/**` if your allow-list is path-scoped)
/// to Supabase Auth redirect URLs.
///
/// Email confirmation lands in the app so Supabase can establish the session.
/// Password reset still uses the marketing `/auth/reset-password` page so the
/// user can choose a new password in the browser.
///
/// Local web dev: add `http://localhost:<flutter-web-port>` to Supabase Auth
/// site URL / redirect allow-list when testing sign-in in Chrome.
class AuthConfig {
  static const String emailRedirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
    defaultValue: 'https://goclarity.app/app/',
  );

  static const String passwordResetRedirectUrl = String.fromEnvironment(
    'SUPABASE_PASSWORD_RESET_REDIRECT_URL',
    defaultValue: 'https://goclarity.app/auth/reset-password',
  );

  /// Primary Flutter web PWA origin (P6 deploy target, `/app/` path on root domain).
  static const String webAppOrigin = 'https://goclarity.app';

  /// Production path prefix when Flutter web is served under the marketing domain.
  static const String webAppPathPrefix = '/app';
}
