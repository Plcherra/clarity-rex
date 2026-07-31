import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import 'auth_config.dart';

final class MfaEnrollment {
  const MfaEnrollment({
    required this.factorId,
    required this.qrCode,
    required this.secret,
    required this.uri,
  });

  final String factorId;
  final String qrCode;
  final String secret;
  final String uri;
}

final class MfaFactorSummary {
  const MfaFactorSummary({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  factory MfaFactorSummary.fromFactor(Factor factor) {
    final friendlyName = factor.friendlyName?.trim();
    return MfaFactorSummary(
      id: factor.id,
      name: friendlyName == null || friendlyName.isEmpty
          ? 'Authenticator app'
          : friendlyName,
      createdAt: factor.createdAt,
    );
  }
}

enum MfaSecurityEmailEvent {
  enabled,
  disabled;

  String get functionValue {
    return switch (this) {
      MfaSecurityEmailEvent.enabled => 'mfa_enabled',
      MfaSecurityEmailEvent.disabled => 'mfa_disabled',
    };
  }
}

class AuthService {
  AuthService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  Session? get currentSession {
    if (!_supabaseService.isConfigured) return null;
    return _supabaseService.auth.currentSession;
  }

  User? get currentUser {
    if (!_supabaseService.isConfigured) return null;
    return _supabaseService.auth.currentUser;
  }

  Stream<AuthState> get authStateChanges {
    if (!_supabaseService.isConfigured) return const Stream.empty();
    return _supabaseService.auth.onAuthStateChange;
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? language,
  }) {
    final normalizedLanguage = language?.trim().toLowerCase();
    return _supabaseService.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: AuthConfig.emailRedirectUrl,
      data: {
        if (normalizedLanguage != null && normalizedLanguage.isNotEmpty)
          'language': normalizedLanguage,
      },
    );
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _supabaseService.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() {
    return _supabaseService.auth.signOut();
  }

  Future<void> requestPasswordReset({required String email}) {
    return _supabaseService.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AuthConfig.passwordResetRedirectUrl,
    );
  }

  Future<void> resendConfirmationEmail({required String email}) {
    return _supabaseService.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: AuthConfig.emailRedirectUrl,
    );
  }

  AuthMFAGetAuthenticatorAssuranceLevelResponse
  getAuthenticatorAssuranceLevel() {
    return _supabaseService.auth.mfa.getAuthenticatorAssuranceLevel();
  }

  bool get isMfaVerificationRequired {
    if (!_supabaseService.isConfigured || currentSession == null) return false;
    final aal = getAuthenticatorAssuranceLevel();
    return aal.currentLevel != null &&
        aal.currentLevel != aal.nextLevel &&
        aal.nextLevel == AuthenticatorAssuranceLevels.aal2;
  }

  Future<MfaEnrollment> enrollTotp({
    String issuer = 'Clarity',
    String friendlyName = 'Clarity Authenticator',
  }) async {
    final response = await _supabaseService.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: issuer,
      friendlyName: friendlyName,
    );
    final totp = response.totp;
    if (totp == null) {
      throw const AuthException(
        'Supabase did not return TOTP enrollment details.',
      );
    }
    return MfaEnrollment(
      factorId: response.id,
      qrCode: totp.qrCode,
      secret: totp.secret,
      uri: totp.uri,
    );
  }

  Future<List<MfaFactorSummary>> verifiedTotpFactors() async {
    final response = await _supabaseService.auth.mfa.listFactors();
    return response.totp.map(MfaFactorSummary.fromFactor).toList();
  }

  Future<void> verifyMfaCode({
    required String factorId,
    required String code,
  }) async {
    await _supabaseService.auth.mfa.challengeAndVerify(
      factorId: factorId,
      code: _digitsOnly(code),
    );
  }

  Future<void> unenrollMfaFactor(String factorId) async {
    await _supabaseService.auth.mfa.unenroll(factorId);
  }

  Future<bool> sendMfaSecurityEmail(MfaSecurityEmailEvent event) async {
    if (!_supabaseService.isConfigured || currentSession == null) {
      return false;
    }
    try {
      final response = await _supabaseService.functions.invoke(
        'send-mfa-security-email',
        body: {'event': event.functionValue},
      );
      return response.status >= 200 && response.status < 300;
    } on Object {
      return false;
    }
  }

  Future<void> deleteAccount() async {
    if (!_supabaseService.isConfigured || currentSession == null) {
      throw const AuthException('You must be signed in to delete your account.');
    }
    final response = await _supabaseService.functions.invoke('delete-account');
    if (response.status < 200 || response.status >= 300) {
      throw AuthException(
        _functionErrorMessage(response.data) ??
            'Could not delete your account. Try again or contact support.',
      );
    }
    try {
      await signOut();
    } on Object {
      // Auth user is already deleted; ignore remote sign-out failures.
    }
  }
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String? _functionErrorMessage(Object? data) {
  if (data is Map) {
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }
  }
  return null;
}
