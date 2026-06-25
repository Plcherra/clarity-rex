/// Supabase Auth redirect targets for email confirmation links.
class AuthConfig {
  static const String emailRedirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
    defaultValue: 'https://goclarity.app/auth/confirmed',
  );
}
