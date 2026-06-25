import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyAuthError(Object error) {
  final message = _authErrorMessage(error);
  if (message == null) {
    return error.toString();
  }

  final normalized = message.toLowerCase();

  if (normalized.contains('invalid login credentials') ||
      normalized.contains('invalid credentials')) {
    return 'Email or password is incorrect. Try again or create a new account.';
  }
  if (normalized.contains('user already registered') ||
      normalized.contains('already been registered') ||
      normalized.contains('already exists')) {
    return 'An account with this email already exists. Sign in instead.';
  }
  if (normalized.contains('email not confirmed') ||
      normalized.contains('confirm your email')) {
    return 'Confirm your email first, then sign in.';
  }
  if (normalized.contains('error sending') &&
      normalized.contains('email')) {
    return 'We could not send a confirmation email right now. Try again in a few minutes.';
  }
  if (normalized.contains('signups not allowed') ||
      normalized.contains('signup is disabled')) {
    return 'New account sign-up is disabled for this app right now.';
  }
  if (normalized.contains('password') &&
      (normalized.contains('at least') || normalized.contains('weak'))) {
    return 'Choose a stronger password and try again.';
  }
  if (isMfaCodeError(normalized)) {
    return 'That code was not accepted. Check your authenticator app and try again.';
  }
  if (normalized.contains('mfa') && normalized.contains('not enabled')) {
    return 'MFA is not enabled for this Supabase project.';
  }
  if (normalized.contains('too many')) {
    return 'Too many attempts. Wait a moment, then try again.';
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
