import 'package:clarity/core/supabase/supabase_service.dart';
import 'package:clarity/features/auth/application/auth_controller.dart';
import 'package:clarity/features/auth/application/auth_service.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user(String id) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    identities: [
      UserIdentity(
        id: 'identity-$id',
        userId: id,
        identityData: const {},
        identityId: 'identity-$id',
        provider: 'email',
        createdAt: '2026-01-01T00:00:00Z',
        lastSignInAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z',
      ),
    ],
  );
}

AuthResponse _pendingSignUpResponse() => AuthResponse(user: _user('user-1'));

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
    authService.signUpResponse = _pendingSignUpResponse();

    await controller.signUpWithEmail(
      email: 'new@example.com',
      password: 'password123',
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

  test('prepareSignInAfterEmailConfirmation prefills sign-in', () {
    controller.pendingConfirmationEmail = 'pending@example.com';

    controller.prepareSignInAfterEmailConfirmation();

    expect(controller.needsEmailConfirmation, isFalse);
    expect(controller.takePrefillEmail(), 'pending@example.com');
    expect(
      controller.infoMessage,
      'Email confirmed. Sign in with your password to continue.',
    );
  });

  test('continueAfterEmailConfirmation signs in with pending password', () async {
    authService.signUpResponse = _pendingSignUpResponse();
    await controller.signUpWithEmail(
      email: 'pending@example.com',
      password: 'password123',
    );

    final user = _user('user-1');
    authService.signInResponse = AuthResponse(
      session: Session(
        accessToken: 'access',
        tokenType: 'bearer',
        user: user,
      ),
    );

    await controller.continueAfterEmailConfirmation();

    expect(authService.signInCalls, 1);
    expect(controller.needsEmailConfirmation, isFalse);
    expect(controller.isAuthenticated, isTrue);
  });

  test('continueAfterEmailConfirmation keeps pending when still unconfirmed', () async {
    authService.signUpResponse = _pendingSignUpResponse();
    await controller.signUpWithEmail(
      email: 'pending@example.com',
      password: 'password123',
    );
    authService.signInError = const AuthException('Email not confirmed');

    await controller.continueAfterEmailConfirmation();

    expect(controller.needsEmailConfirmation, isTrue);
    expect(
      controller.infoMessage,
      'Email is not confirmed yet. Open the link from your inbox, then return here.',
    );
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
  AuthResponse? signInResponse;
  AuthException? signInError;
  Session? _session;
  int resendCalls = 0;
  int signInCalls = 0;
  int deleteAccountCalls = 0;
  String? lastResendEmail;

  @override
  Session? get currentSession => _session;

  @override
  User? get currentUser => _session?.user;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  bool get isMfaVerificationRequired => false;

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? language,
  }) async {
    return signUpResponse!;
  }

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls += 1;
    final error = signInError;
    if (error != null) throw error;
    final response = signInResponse ?? AuthResponse();
    _session = response.session;
    return response;
  }

  @override
  Future<Session?> refreshAuthSession() async => _session;

  @override
  Future<void> resendConfirmationEmail({required String email}) async {
    resendCalls += 1;
    lastResendEmail = email;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls += 1;
    _session = null;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> signOut() async {
    _session = null;
  }
}
