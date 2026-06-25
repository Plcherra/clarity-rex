import 'package:clarity/features/auth/application/auth_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('invalid login credentials are not shown as MFA errors', () {
    expect(
      friendlyAuthError(const AuthException('Invalid login credentials')),
      'Email or password is incorrect. Try again or create a new account.',
    );
  });

  test('duplicate signup shows account exists message', () {
    expect(
      friendlyAuthError(const AuthException('User already registered')),
      'An account with this email already exists. Sign in instead.',
    );
  });

  test('invalid TOTP codes keep authenticator guidance', () {
    expect(
      friendlyAuthError(const AuthException('Invalid TOTP code entered')),
      'That code was not accepted. Check your authenticator app and try again.',
    );
  });

  test('email send failures are not shown as MFA errors', () {
    expect(
      friendlyAuthError(
        const AuthException('Error sending confirmation email'),
      ),
      'We could not send a confirmation email right now. Try again in a few minutes.',
    );
  });
}
