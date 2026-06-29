import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_gradients.dart';
import '../../../widgets/clarity_button.dart';
import '../../../widgets/clarity_card.dart';
import '../application/auth_controller.dart';

final class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

final class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();

    setState(() => _localError = null);
    if (email.isEmpty || password.isEmpty) {
      setState(() => _localError = context.l10n.authEnterEmailPassword);
      return;
    }
    if (_isSignUp && fullName.isEmpty) {
      setState(() => _localError = context.l10n.authEnterName);
      return;
    }

    if (_isSignUp) {
      await widget.controller.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
    } else {
      await widget.controller.signInWithEmail(email: email, password: password);
    }
  }

  Future<void> _requestPasswordReset() async {
    final email = _emailController.text.trim();
    setState(() => _localError = null);
    if (email.isEmpty) {
      setState(() => _localError = context.l10n.authEnterEmailForReset);
      return;
    }
    await widget.controller.requestPasswordReset(email: email);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final l10n = context.l10n;
        final error = _localError ?? widget.controller.errorMessage;
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: ClarityGradients.appBackground,
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ClarityCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/brand/clarity_mark.png',
                              width: 72,
                              height: 72,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            _isSignUp
                                ? l10n.authSignUpTitle
                                : l10n.authSignInTitle,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSignUp
                                ? l10n.authSignUpSubtitle
                                : l10n.authSignInSubtitle,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (_isSignUp) ...[
                            TextField(
                              controller: _fullNameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.authFullNameLabel,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.authEmailLabel,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: l10n.authPasswordLabel,
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? l10n.authShowPassword
                                    : l10n.authHidePassword,
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (!_isSignUp) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: widget.controller.isLoading
                                    ? null
                                    : _requestPasswordReset,
                                child: Text(l10n.authForgotPassword),
                              ),
                            ),
                          ],
                          if (error != null && error.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              error,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (widget.controller.infoMessage != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              widget.controller.infoMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          ClarityButton.filled(
                            label: _isSignUp
                                ? l10n.authCreateAccountButton
                                : l10n.authSignInButton,
                            onPressed: _submit,
                            isLoading: widget.controller.isLoading,
                            expanded: true,
                          ),
                          const SizedBox(height: 12),
                          ClarityButton.text(
                            label: _isSignUp
                                ? l10n.authSwitchToSignIn
                                : l10n.authSwitchToSignUp,
                            onPressed: widget.controller.isLoading
                                ? null
                                : () {
                                    widget.controller.clearAuthMessages();
                                    setState(() {
                                      _localError = null;
                                      _isSignUp = !_isSignUp;
                                    });
                                  },
                            expanded: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
