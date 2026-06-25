import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_error_messages.dart';
import 'auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthService authService,
    bool initialAuthenticated = false,
  }) : _authService = authService,
       _authenticatedOverride = initialAuthenticated {
    _session = _authService.currentSession;
    _syncMfaRequirement();
    _subscription = _authService.authStateChanges.listen((state) {
      _session = state.session;
      _authenticatedOverride = false;
      _syncMfaRequirement();
      notifyListeners();
    });
  }

  final AuthService _authService;
  StreamSubscription<AuthState>? _subscription;
  Session? _session;
  bool _authenticatedOverride;

  bool isLoading = false;
  bool isMfaLoading = false;
  bool isMfaRequired = false;
  String? errorMessage;
  String? infoMessage;
  String? mfaErrorMessage;
  String? mfaInfoMessage;
  MfaEnrollment? pendingMfaEnrollment;
  List<MfaFactorSummary> mfaFactors = const [];

  Session? get currentSession => _session;
  User? get currentUser => _session?.user ?? _authService.currentUser;
  bool get isAuthenticated => _authenticatedOverride || currentSession != null;
  bool get hasVerifiedTotpFactor => mfaFactors.isNotEmpty;

  void clearAuthMessages() {
    errorMessage = null;
    infoMessage = null;
    notifyListeners();
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    await _runAuthAction(() async {
      final response = await _authService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      _session = response.session;
      _syncMfaRequirement();
      if (_session == null) {
        infoMessage = 'Check your email to confirm your account.';
      }
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      final response = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _session = response.session;
      _syncMfaRequirement();
      if (isMfaRequired) {
        infoMessage = 'Enter your authenticator code to finish signing in.';
      }
    });
  }

  Future<void> signOut() async {
    await _runAuthAction(() async {
      await _authService.signOut();
      _session = null;
      _authenticatedOverride = false;
      _clearMfaState();
    });
  }

  Future<void> cancelMfaSignIn() async {
    await signOut();
  }

  Future<void> loadMfaFactors() async {
    await _runMfaAction(() async {
      mfaFactors = await _authService.verifiedTotpFactors();
      if (mfaFactors.isEmpty && isMfaRequired) {
        mfaErrorMessage =
            'No verified authenticator app is available for this account.';
      }
    });
  }

  Future<void> beginMfaEnrollment() async {
    await _runMfaAction(() async {
      pendingMfaEnrollment = await _authService.enrollTotp();
      mfaInfoMessage =
          'Scan the QR code, then enter the 6-digit code from your app.';
    });
  }

  Future<void> verifyMfaEnrollment({required String code}) async {
    final enrollment = pendingMfaEnrollment;
    if (enrollment == null) {
      mfaErrorMessage = 'Start MFA enrollment before verifying a code.';
      notifyListeners();
      return;
    }
    await _runMfaAction(() async {
      await _authService.verifyMfaCode(
        factorId: enrollment.factorId,
        code: code,
      );
      _session = _authService.currentSession;
      pendingMfaEnrollment = null;
      await _refreshMfaStateAfterVerification();
      final emailSent = await _authService.sendMfaSecurityEmail(
        MfaSecurityEmailEvent.enabled,
      );
      mfaInfoMessage = emailSent
          ? 'MFA is enabled. We sent you a confirmation email.'
          : 'MFA is enabled. Confirmation email could not be sent right now.';
    });
  }

  Future<void> verifyMfaSignIn({required String code, String? factorId}) async {
    await _runMfaAction(() async {
      var resolvedFactorId = factorId;
      if (resolvedFactorId == null || resolvedFactorId.isEmpty) {
        if (mfaFactors.isEmpty) {
          mfaFactors = await _authService.verifiedTotpFactors();
        }
        if (mfaFactors.isEmpty) {
          throw const AuthException(
            'No verified authenticator app is available for this account.',
          );
        }
        resolvedFactorId = mfaFactors.first.id;
      }
      await _authService.verifyMfaCode(factorId: resolvedFactorId, code: code);
      _session = _authService.currentSession;
      await _refreshMfaStateAfterVerification();
      mfaInfoMessage = 'Sign-in verified.';
    });
  }

  Future<void> refreshMfaFactors() async {
    await loadMfaFactors();
  }

  Future<void> unenrollMfaFactor(String factorId) async {
    await _runMfaAction(() async {
      final hadSingleFactor = mfaFactors.length == 1;
      await _authService.unenrollMfaFactor(factorId);
      mfaFactors = await _authService.verifiedTotpFactors();
      _syncMfaRequirement();
      if (hadSingleFactor && mfaFactors.isEmpty) {
        final emailSent = await _authService.sendMfaSecurityEmail(
          MfaSecurityEmailEvent.disabled,
        );
        mfaInfoMessage = emailSent
            ? 'MFA is off. We sent you a confirmation email.'
            : 'MFA is off. Confirmation email could not be sent right now.';
      } else {
        mfaInfoMessage = 'Authenticator app removed.';
      }
    });
  }

  Future<void> disableMfa() async {
    await _runMfaAction(() async {
      if (mfaFactors.isEmpty) {
        mfaFactors = await _authService.verifiedTotpFactors();
      }
      final factorsToRemove = List<MfaFactorSummary>.of(mfaFactors);
      if (factorsToRemove.isEmpty) {
        pendingMfaEnrollment = null;
        _syncMfaRequirement();
        mfaInfoMessage = 'MFA is already off.';
        return;
      }
      for (final factor in factorsToRemove) {
        await _authService.unenrollMfaFactor(factor.id);
      }
      mfaFactors = await _authService.verifiedTotpFactors();
      pendingMfaEnrollment = null;
      _syncMfaRequirement();
      final emailSent = await _authService.sendMfaSecurityEmail(
        MfaSecurityEmailEvent.disabled,
      );
      mfaInfoMessage = emailSent
          ? 'MFA is off. We sent you a confirmation email.'
          : 'MFA is off. Confirmation email could not be sent right now.';
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      errorMessage = friendlyAuthError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _runMfaAction(Future<void> Function() action) async {
    isMfaLoading = true;
    mfaErrorMessage = null;
    mfaInfoMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      mfaErrorMessage = friendlyAuthError(e);
    } finally {
      isMfaLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshMfaStateAfterVerification() async {
    _syncMfaRequirement();
    mfaFactors = await _authService.verifiedTotpFactors();
  }

  void _syncMfaRequirement() {
    try {
      isMfaRequired = _authService.isMfaVerificationRequired;
    } on Object {
      isMfaRequired = false;
    }
  }

  void _clearMfaState() {
    isMfaRequired = false;
    isMfaLoading = false;
    pendingMfaEnrollment = null;
    mfaFactors = const [];
    mfaErrorMessage = null;
    mfaInfoMessage = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
