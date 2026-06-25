import 'package:supabase_flutter/supabase_flutter.dart';

enum SignUpStatus {
  signedIn,
  needsEmailConfirmation,
  emailAlreadyRegistered,
}

SignUpStatus signUpStatus(AuthResponse response) {
  final user = response.user;
  if (user != null && (user.identities == null || user.identities!.isEmpty)) {
    return SignUpStatus.emailAlreadyRegistered;
  }
  if (response.session != null) {
    return SignUpStatus.signedIn;
  }
  return SignUpStatus.needsEmailConfirmation;
}
