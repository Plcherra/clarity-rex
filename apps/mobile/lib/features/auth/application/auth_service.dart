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
    String? fullName,
  }) {
    return _supabaseService.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: AuthConfig.emailRedirectUrl,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
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
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}
