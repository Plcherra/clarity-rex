import 'package:clarity/features/auth/application/auth_error_messages.dart';
import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final l10n = lookupEnglishLocalizationsForTests();

  test('invalid login credentials are not shown as MFA errors', () {
    expect(
      friendlyAuthError(const AuthException('Invalid login credentials'), l10n),
      l10n.authErrorInvalidCredentials,
    );
  });

  test('duplicate signup shows account exists message', () {
    expect(
      friendlyAuthError(const AuthException('User already registered'), l10n),
      l10n.authErrorAccountExists,
    );
  });

  test('invalid TOTP codes keep authenticator guidance', () {
    expect(
      friendlyAuthError(const AuthException('Invalid TOTP code entered'), l10n),
      l10n.authErrorMfaCodeRejected,
    );
  });

  test('email send failures are not shown as MFA errors', () {
    expect(
      friendlyAuthError(
        const AuthException('Error sending confirmation email'),
        l10n,
      ),
      l10n.authErrorEmailSendFailed,
    );
  });
}
