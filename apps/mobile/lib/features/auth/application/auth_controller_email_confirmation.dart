part of 'auth_controller.dart';

extension AuthControllerEmailConfirmation on AuthController {
  void clearPendingEmailConfirmation() {
    pendingConfirmationEmail = null;
    _pendingConfirmationPassword = null;
    errorMessage = null;
    infoMessage = null;
    publishAuthState();
  }

  /// Leaves the confirm-email screen and returns to sign-in with email ready.
  void prepareSignInAfterEmailConfirmation() {
    if (!needsEmailConfirmation) return;
    final email = pendingConfirmationEmail?.trim();
    pendingConfirmationEmail = null;
    _pendingConfirmationPassword = null;
    if (email != null && email.isNotEmpty) {
      prefillEmail = email;
    }
    errorMessage = null;
    infoMessage = l10n.authInfoEmailConfirmedSignIn;
    publishAuthState();
  }

  /// Refresh session after email link / resume; enter app or fall back to sign-in.
  Future<void> continueAfterEmailConfirmation() async {
    if (!needsEmailConfirmation && currentSession == null) return;
    await _runAuthAction(() async {
      final refreshed = await _authService.refreshAuthSession();
      final session = refreshed ?? _authService.currentSession;
      if (session != null) {
        pendingConfirmationEmail = null;
        _pendingConfirmationPassword = null;
        _session = session;
        _syncMfaRequirement();
        return;
      }

      final email = pendingConfirmationEmail?.trim();
      final password = _pendingConfirmationPassword;
      if (email != null &&
          email.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
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
          return;
        } on AuthException catch (error) {
          if (_isEmailNotConfirmedError(error)) {
            errorMessage = null;
            infoMessage = l10n.authConfirmEmailStillPending;
            return;
          }
          rethrow;
        }
      }

      prepareSignInAfterEmailConfirmation();
    });
  }
}
