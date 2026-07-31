import 'package:clarity/core/supabase/supabase_service.dart';
import 'package:clarity/features/auth/application/auth_controller.dart';
import 'package:clarity/features/auth/application/auth_service.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late _FakeAuthService authService;
  late AuthController controller;

  setUp(() {
    authService = _FakeAuthService();
    controller = AuthController(
      authService: authService,
      l10n: () => lookupAppLocalizations(const Locale('en')),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('signup without session shows email confirmation pending state', () async {
    authService.signUpResponse = AuthResponse(
      user: User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
        identities: const [
          UserIdentity(
            id: 'identity-1',
            userId: 'user-1',
            identityData: {},
            identityId: 'identity-1',
            provider: 'email',
            createdAt: '2026-01-01T00:00:00Z',
            lastSignInAt: '2026-01-01T00:00:00Z',
            updatedAt: '2026-01-01T00:00:00Z',
          ),
        ],
      ),
    );

    await controller.signUpWithEmail(
      email: 'new@example.com',
      password: 'password123',
      fullName: 'New User',
    );

    expect(controller.needsEmailConfirmation, isTrue);
    expect(controller.pendingConfirmationEmail, 'new@example.com');
    expect(controller.isAuthenticated, isFalse);
    expect(controller.infoMessage, isNull);
  });

  test('unconfirmed sign-in routes to email confirmation', () async {
    authService.signInError = const AuthException('Email not confirmed');

    await controller.signInWithEmail(
      email: 'pending@example.com',
      password: 'password123',
    );

    expect(controller.needsEmailConfirmation, isTrue);
    expect(controller.pendingConfirmationEmail, 'pending@example.com');
    expect(controller.errorMessage, isNull);
    expect(controller.isAuthenticated, isFalse);
  });

  test('resend confirmation email keeps pending email and sets info', () async {
    controller.pendingConfirmationEmail = 'pending@example.com';

    await controller.resendConfirmationEmail();

    expect(authService.resendCalls, 1);
    expect(authService.lastResendEmail, 'pending@example.com');
    expect(controller.needsEmailConfirmation, isTrue);
    expect(
      controller.infoMessage,
      'Confirmation email sent again to pending@example.com.',
    );
  });

  test('clearPendingEmailConfirmation returns to auth form state', () {
    controller.pendingConfirmationEmail = 'pending@example.com';
    controller.infoMessage = 'sent';

    controller.clearPendingEmailConfirmation();

    expect(controller.needsEmailConfirmation, isFalse);
    expect(controller.pendingConfirmationEmail, isNull);
    expect(controller.infoMessage, isNull);
  });

  test('deleteAccount clears local session state', () async {
    final deleteController = AuthController(
      authService: authService,
      initialAuthenticated: true,
      l10n: () => lookupAppLocalizations(const Locale('en')),
    );
    addTearDown(deleteController.dispose);

    await deleteController.deleteAccount();

    expect(authService.deleteAccountCalls, 1);
    expect(deleteController.isAuthenticated, isFalse);
    expect(deleteController.errorMessage, isNull);
  });
}

final class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(supabaseService: const SupabaseService());

  AuthResponse? signUpResponse;
  AuthException? signInError;
  int resendCalls = 0;
  int deleteAccountCalls = 0;
  String? lastResendEmail;

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  bool get isMfaVerificationRequired => false;

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return signUpResponse!;
  }

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final error = signInError;
    if (error != null) throw error;
    return AuthResponse();
  }

  @override
  Future<void> resendConfirmationEmail({required String email}) async {
    resendCalls += 1;
    lastResendEmail = email;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls += 1;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> signOut() async {}
}
