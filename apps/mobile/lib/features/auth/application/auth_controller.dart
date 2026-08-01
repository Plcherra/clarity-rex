import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import 'auth_error_messages.dart';
import 'auth_service.dart';
import 'auth_signup.dart';

part 'auth_controller_email_confirmation.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthService authService,
    bool initialAuthenticated = false,
    AppLocalizations Function()? l10n,
  }) : _authService = authService,
       _authenticatedOverride = initialAuthenticated,
       _l10n = l10n ?? _throwUnboundL10n {
    _session = _authService.currentSession;
    _syncMfaRequirement();
    _subscription = _authService.authStateChanges.listen((state) {
      _session = state.session;
      _authenticatedOverride = false;
      if (_session != null) {
        pendingConfirmationEmail = null;
        _pendingConfirmationPassword = null;
      }
      _syncMfaRequirement();
      notifyListeners();
    });
  }

  final AuthService _authService;
  static AppLocalizations Function() get _throwUnboundL10n =>
      () => throw StateError(
        'AuthController requires l10n. '
        'Pass l10n to the constructor or call bindLocalizations() first.',
      );
  AppLocalizations Function() _l10n;
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
  String? pendingConfirmationEmail;
  String? prefillEmail;

  /// Held only while waiting for email confirm so "I've confirmed" can sign in.
  String? _pendingConfirmationPassword;
  MfaEnrollment? pendingMfaEnrollment;
  List<MfaFactorSummary> mfaFactors = const [];

  Session? get currentSession => _session;
  User? get currentUser => _session?.user ?? _authService.currentUser;
  bool get isAuthenticated => _authenticatedOverride || currentSession != null;
  bool get needsEmailConfirmation =>
      !isAuthenticated &&
      pendingConfirmationEmail != null &&
      pendingConfirmationEmail!.trim().isNotEmpty;
  bool get hasVerifiedTotpFactor => mfaFactors.isNotEmpty;

  AppLocalizations get l10n => _l10n();

  void bindLocalizations(AppLocalizations localizations) {
    _l10n = () => localizations;
  }

  void clearAuthMessages() {
    errorMessage = null;
    infoMessage = null;
    notifyListeners();
  }

  /// Republishes state for the extensions in this library's part files.
  ///
  /// `notifyListeners` is protected on [ChangeNotifier], and an extension is
  /// not a subclass, so it cannot reach it directly.
  void publishAuthState() => notifyListeners();

  String? takePrefillEmail() {
    final email = prefillEmail?.trim();
    prefillEmail = null;
    if (email == null || email.isEmpty) return null;
    return email;
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? language,
  }) async {
    await _runAuthAction(() async {
      final response = await _authService.signUpWithEmail(
        email: email,
        password: password,
        language: language,
      );
      switch (signUpStatus(response)) {
        case SignUpStatus.emailAlreadyRegistered:
          throw AuthException(l10n.authErrorAccountExists);
        case SignUpStatus.signedIn:
          pendingConfirmationEmail = null;
          _pendingConfirmationPassword = null;
          _session = response.session;
          _syncMfaRequirement();
          infoMessage = l10n.authInfoAccountCreatedSignedIn;
        case SignUpStatus.needsEmailConfirmation:
          _session = response.session;
          _syncMfaRequirement();
          pendingConfirmationEmail = email.trim();
          _pendingConfirmationPassword = password;
          infoMessage = null;
      }
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      try {
        final response = await _authService.signInWithEmail(
          email: email,
          password: password,
        );
        pendingConfirmationEmail = null;
        _pendingConfirmationPassword = null;
        _session = response.session;
        _syncMfaRequirement();
        if (isMfaRequired) {
          infoMessage = l10n.authInfoEnterAuthenticatorCode;
        }
      } on AuthException catch (error) {
        if (_isEmailNotConfirmedError(error)) {
          pendingConfirmationEmail = email.trim();
          errorMessage = null;
          infoMessage = null;
          return;
        }
        rethrow;
      }
    });
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _runAuthAction(() async {
      await _authService.requestPasswordReset(email: email);
      infoMessage = l10n.authInfoPasswordResetSent(email);
    });
  }

  Future<void> resendConfirmationEmail() async {
    final email = pendingConfirmationEmail?.trim();
    if (email == null || email.isEmpty) {
      errorMessage = l10n.authEnterEmailForReset;
      notifyListeners();
      return;
    }
    await _runAuthAction(() async {
      pendingConfirmationEmail = email;
      await _authService.resendConfirmationEmail(email: email);
      infoMessage = l10n.authConfirmEmailResent(email);
    });
  }

  Future<void> signOut() async {
    await _runAuthAction(() async {
      await _authService.signOut();
      _session = null;
      _authenticatedOverride = false;
      pendingConfirmationEmail = null;
      _pendingConfirmationPassword = null;
      _clearMfaState();
    });
  }

  Future<void> deleteAccount() async {
    await _runAuthAction(() async {
      await _authService.deleteAccount();
      _session = null;
      _authenticatedOverride = false;
      pendingConfirmationEmail = null;
      _pendingConfirmationPassword = null;
      _clearMfaState();
    });
  }

  /// Asks Supabase to email a confirmation link for a new address.
  ///
  /// Returns true when the email went out — not when the address changed. It
  /// changes only after the link is opened, which happens outside the app.
  Future<bool> requestEmailChange(String email) async {
    var sent = false;
    await _runAuthAction(() async {
      await _authService.requestEmailChange(email: email);
      sent = true;
    });
    return sent;
  }

  Future<void> cancelMfaSignIn() async {
    await signOut();
  }

  Future<void> loadMfaFactors() async {
    await _runMfaAction(() async {
      mfaFactors = await _authService.verifiedTotpFactors();
      if (mfaFactors.isEmpty && isMfaRequired) {
        mfaErrorMessage = l10n.authErrorNoAuthenticatorAvailable;
      }
    });
  }

  Future<void> beginMfaEnrollment() async {
    await _runMfaAction(() async {
      pendingMfaEnrollment = await _authService.enrollTotp();
      mfaInfoMessage = l10n.authInfoMfaEnrollmentStart;
    });
  }

  Future<void> verifyMfaEnrollment({required String code}) async {
    final enrollment = pendingMfaEnrollment;
    if (enrollment == null) {
      mfaErrorMessage = l10n.authErrorStartEnrollmentFirst;
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
          ? l10n.authInfoMfaEnabledEmailSent
          : l10n.authInfoMfaEnabledEmailFailed;
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
          throw AuthException(l10n.authErrorNoAuthenticatorAvailable);
        }
        resolvedFactorId = mfaFactors.first.id;
      }
      await _authService.verifyMfaCode(factorId: resolvedFactorId, code: code);
      _session = _authService.currentSession;
      await _refreshMfaStateAfterVerification();
      mfaInfoMessage = l10n.authInfoSignInVerified;
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
            ? l10n.authInfoMfaDisabledEmailSent
            : l10n.authInfoMfaDisabledEmailFailed;
      } else {
        mfaInfoMessage = l10n.authInfoAuthenticatorRemoved;
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
        mfaInfoMessage = l10n.authInfoMfaAlreadyOff;
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
          ? l10n.authInfoMfaDisabledEmailSent
          : l10n.authInfoMfaDisabledEmailFailed;
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
      debugPrint('[Clarity][Auth] $e');
      errorMessage = friendlyAuthError(e, l10n);
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
      mfaErrorMessage = friendlyAuthError(e, l10n);
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

  bool _isEmailNotConfirmedError(AuthException error) {
    final normalized = error.message.toLowerCase();
    return normalized.contains('email not confirmed') ||
        normalized.contains('confirm your email');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
