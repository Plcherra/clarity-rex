import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';

String friendlyAuthError(Object error, AppLocalizations l10n) {
  final message = _authErrorMessage(error);
  if (message == null) {
    return error.toString();
  }

  final normalized = message.toLowerCase();

  if (normalized.contains('invalid login credentials') ||
      normalized.contains('invalid credentials')) {
    return l10n.authErrorInvalidCredentials;
  }
  if (normalized.contains('user already registered') ||
      normalized.contains('already been registered') ||
      normalized.contains('already exists')) {
    return l10n.authErrorAccountExists;
  }
  if (normalized.contains('email not confirmed') ||
      normalized.contains('confirm your email')) {
    return l10n.authErrorEmailNotConfirmed;
  }
  if (normalized.contains('error sending') &&
      normalized.contains('email')) {
    return l10n.authErrorEmailSendFailed;
  }
  if (normalized.contains('signups not allowed') ||
      normalized.contains('signup is disabled')) {
    return l10n.authErrorSignupsDisabled;
  }
  if (normalized.contains('password') &&
      (normalized.contains('at least') || normalized.contains('weak'))) {
    return l10n.authErrorWeakPassword;
  }
  if (isMfaCodeError(normalized)) {
    return l10n.authErrorMfaCodeRejected;
  }
  if (normalized.contains('mfa') && normalized.contains('not enabled')) {
    return l10n.authErrorMfaNotEnabled;
  }
  if (normalized.contains('too many')) {
    return l10n.authErrorTooManyAttempts;
  }
  return message;
}

String? _authErrorMessage(Object error) {
  if (error is AuthException) {
    return error.message;
  }
  return _readStringProperty(error, 'message');
}

String? _readStringProperty(Object error, String property) {
  try {
    final dynamic value = (error as dynamic)[property];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  } on Object {
    return null;
  }
  return null;
}

bool isMfaCodeError(String normalized) {
  final mentionsMfa =
      normalized.contains('otp') ||
      normalized.contains('totp') ||
      normalized.contains('mfa') ||
      normalized.contains('authenticator') ||
      normalized.contains('verification code');
  final mentionsFailure =
      normalized.contains('invalid') ||
      normalized.contains('expired') ||
      normalized.contains('incorrect') ||
      normalized.contains('wrong') ||
      normalized.contains('not accepted');
  return mentionsMfa && mentionsFailure;
}
