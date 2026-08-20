/// Client-side create-account password rules.
///
/// Sign-in does not use this — existing passwords may be weaker.
/// Server `weak` / `at least` errors still map to the friendly weak-password string.
final class AuthPasswordStrength {
  const AuthPasswordStrength({
    required this.hasMinLength,
    required this.hasLowercase,
    required this.hasUppercase,
    required this.hasDigit,
  });

  static const minLength = 8;

  static final _lowercase = RegExp(r'[a-z]');
  static final _uppercase = RegExp(r'[A-Z]');
  static final _digit = RegExp(r'[0-9]');

  factory AuthPasswordStrength.evaluate(String password) {
    return AuthPasswordStrength(
      hasMinLength: password.length >= minLength,
      hasLowercase: _lowercase.hasMatch(password),
      hasUppercase: _uppercase.hasMatch(password),
      hasDigit: _digit.hasMatch(password),
    );
  }

  final bool hasMinLength;
  final bool hasLowercase;
  final bool hasUppercase;
  final bool hasDigit;

  bool get isStrong =>
      hasMinLength && hasLowercase && hasUppercase && hasDigit;
}
