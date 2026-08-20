import 'package:clarity/features/auth/application/auth_password_strength.dart';
import 'package:clarity/features/auth/presentation/auth_password_field.dart';
import 'package:clarity/features/auth/presentation/auth_password_strength_checklist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  group('AuthPasswordStrength', () {
    test('empty fails every rule and the all-four gate', () {
      final strength = AuthPasswordStrength.evaluate('');
      expect(strength.hasMinLength, isFalse);
      expect(strength.hasLowercase, isFalse);
      expect(strength.hasUppercase, isFalse);
      expect(strength.hasDigit, isFalse);
      expect(strength.isStrong, isFalse);
    });

    test('length requires at least 8 characters', () {
      expect(AuthPasswordStrength.evaluate('Pass1').hasMinLength, isFalse);
      expect(AuthPasswordStrength.evaluate('Passwor1').hasMinLength, isTrue);
    });

    test('lowercase requires one a-z', () {
      expect(AuthPasswordStrength.evaluate('PASSWORD1').hasLowercase, isFalse);
      expect(AuthPasswordStrength.evaluate('Password1').hasLowercase, isTrue);
    });

    test('uppercase requires one A-Z', () {
      expect(AuthPasswordStrength.evaluate('password1').hasUppercase, isFalse);
      expect(AuthPasswordStrength.evaluate('Password1').hasUppercase, isTrue);
    });

    test('digit requires one 0-9', () {
      expect(AuthPasswordStrength.evaluate('Password').hasDigit, isFalse);
      expect(AuthPasswordStrength.evaluate('Password1').hasDigit, isTrue);
    });

    test('symbol is not required', () {
      expect(AuthPasswordStrength.evaluate('Password1').isStrong, isTrue);
    });

    test('all four must pass the create-account gate', () {
      expect(AuthPasswordStrength.evaluate('short').isStrong, isFalse);
      expect(AuthPasswordStrength.evaluate('password').isStrong, isFalse);
      expect(AuthPasswordStrength.evaluate('Password').isStrong, isFalse);
      expect(AuthPasswordStrength.evaluate('PASSWORD1').isStrong, isFalse);
      expect(AuthPasswordStrength.evaluate('Password1').isStrong, isTrue);
    });
  });

  testWidgets('visibility toggle flips obscureText', (tester) async {
    var obscure = true;
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AuthPasswordField(
                controller: TextEditingController(text: 'secret'),
                obscurePassword: obscure,
                onToggleObscure: () => setState(() => obscure = !obscure),
                onSubmitted: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byKey(const Key('authPasswordField'))).obscureText,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('authPasswordVisibilityToggle')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('authPasswordField'))).obscureText,
      isFalse,
    );
  });

  testWidgets('checklist marks met rules and stays muted for unmet', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10nScaffold(
        AuthPasswordStrengthChecklist(
          strength: AuthPasswordStrength.evaluate('password'),
        ),
      ),
    );

    expect(find.byKey(const Key('authPasswordStrengthChecklist')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));
  });
}
