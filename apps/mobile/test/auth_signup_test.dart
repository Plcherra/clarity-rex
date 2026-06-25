import 'package:clarity/features/auth/application/auth_signup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('duplicate signup is detected when identities are empty', () {
    final response = AuthResponse(
      user: User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
        identities: const [],
      ),
    );

    expect(signUpStatus(response), SignUpStatus.emailAlreadyRegistered);
  });

  test('new signup without session needs email confirmation', () {
    final response = AuthResponse(
      user: User(
        id: 'user-2',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
        identities: const [
          UserIdentity(
            id: 'identity-1',
            userId: 'user-2',
            identityData: {},
            identityId: 'identity-1',
            provider: 'email',
            createdAt: '2026-01-01T00:00:00Z',
            lastSignInAt: '2026-01-01T00:00:00Z',
          ),
        ],
      ),
    );

    expect(signUpStatus(response), SignUpStatus.needsEmailConfirmation);
  });
}
