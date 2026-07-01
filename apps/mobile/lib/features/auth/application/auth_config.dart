/// Supabase Auth redirect targets for email links opened in the browser.
///
/// Production web app lives on the root domain at `/app/` (see
/// `docs/flutter-web/00_FLUTTER_WEB_MASTER.md`). Add `https://goclarity.app`
/// to Supabase Auth redirect allow-list alongside marketing auth pages.
/// Email confirmation and password-reset links continue to land on
/// `goclarity.app/auth/*` pages served by `apps/web`.
/// Local web dev: add `http://localhost:<flutter-web-port>` to Supabase Auth
/// site URL / redirect allow-list when testing sign-in in Chrome.
class AuthConfig {
  static const String emailRedirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
    defaultValue: 'https://goclarity.app/auth/confirmed',
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
