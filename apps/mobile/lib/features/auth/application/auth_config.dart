/// Supabase Auth redirect targets for email links opened in the mobile browser.
class AuthConfig {
  static const String emailRedirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
    defaultValue: 'https://goclarity.app/auth/confirmed',
  );

  static const String passwordResetRedirectUrl = String.fromEnvironment(
    'SUPABASE_PASSWORD_RESET_REDIRECT_URL',
    defaultValue: 'https://goclarity.app/auth/reset-password',
  );
}
