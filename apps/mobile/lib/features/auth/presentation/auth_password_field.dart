import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';

/// Shared Sign in / Create account password field with a tappable eye.
///
/// Uses [InputDecoration.suffixIcon] plus a transparent [Material] so web
/// and iOS both receive the toggle tap. Do not add a second password field.
final class AuthPasswordField extends StatelessWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextField(
      key: const Key('authPasswordField'),
      controller: controller,
      obscureText: obscurePassword,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        labelText: l10n.authPasswordLabel,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        suffixIcon: Material(
          type: MaterialType.transparency,
          child: IconButton(
            key: const Key('authPasswordVisibilityToggle'),
            tooltip: obscurePassword
                ? l10n.authShowPassword
                : l10n.authHidePassword,
            onPressed: onToggleObscure,
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
    );
  }
}
