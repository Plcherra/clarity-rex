import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/l10n/clarity_locale_catalog.dart';
import '../../../theme/clarity_gradients.dart';
import '../../../widgets/clarity_button.dart';
import '../../../widgets/clarity_card.dart';
import '../../profile/application/locale_controller.dart';
import '../application/auth_controller.dart';
import '../application/auth_password_strength.dart';
import 'auth_password_field.dart';
import 'auth_password_strength_checklist.dart';

final class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.controller,
    required this.localeController,
  });

  final AuthController controller;
  final LocaleController localeController;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

final class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.bindLocalizations(context.l10n);
    _applyPrefillEmail();
  }

  void _applyPrefillEmail() {
    final email = widget.controller.takePrefillEmail();
    if (email == null) return;
    _emailController.text = email;
    setState(() {
      _isSignUp = false;
      _localError = null;
    });
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _localError = null);
    if (email.isEmpty || password.isEmpty) {
      setState(() => _localError = context.l10n.authEnterEmailPassword);
      return;
    }
    if (_isSignUp && !AuthPasswordStrength.evaluate(password).isStrong) {
      setState(() => _localError = context.l10n.authPasswordRulesIncomplete);
      return;
    }

    if (_isSignUp) {
      await widget.controller.signUpWithEmail(
        email: email,
        password: password,
        language: widget.localeController.languageCode,
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

  Future<void> _onLanguageChanged(Locale locale) async {
    await widget.localeController.setLocale(locale, persistProfile: false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.localeController,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final l10n = context.l10n;
        final error = _localError ?? widget.controller.errorMessage;
        final passwordStrength = AuthPasswordStrength.evaluate(
          _passwordController.text,
        );
        final canCreateAccount = !_isSignUp || passwordStrength.isStrong;
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(
                                'assets/brand/clarity_mark.png',
                                width: 56,
                                height: 56,
                              ),
                              const Spacer(),
                              _AuthLanguageChooser(
                                localeController: widget.localeController,
                                enabled: !widget.controller.isLoading,
                                onChanged: _onLanguageChanged,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 24),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.authEmailLabel,
                            ),
                          ),
                          const SizedBox(height: 14),
                          AuthPasswordField(
                            controller: _passwordController,
                            obscurePassword: _obscurePassword,
                            onToggleObscure: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            onSubmitted: _submit,
                          ),
                          if (_isSignUp)
                            AuthPasswordStrengthChecklist(
                              strength: passwordStrength,
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
                          GestureDetector(
                            key: const Key('authCreateAccountBlockedTap'),
                            behavior: HitTestBehavior.opaque,
                            onTap: canCreateAccount
                                ? null
                                : () {
                                    setState(() {
                                      _localError =
                                          l10n.authPasswordRulesIncomplete;
                                    });
                                  },
                            child: ClarityButton.filled(
                              key: const Key('authPrimaryButton'),
                              label: _isSignUp
                                  ? l10n.authCreateAccountButton
                                  : l10n.authSignInButton,
                              onPressed: canCreateAccount ? _submit : null,
                              isLoading: widget.controller.isLoading,
                              expanded: true,
                            ),
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

final class _AuthLanguageChooser extends StatelessWidget {
  const _AuthLanguageChooser({
    required this.localeController,
    required this.enabled,
    required this.onChanged,
  });

  final LocaleController localeController;
  final bool enabled;
  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedTag = localeController.localeTag;

    return Semantics(
      label: context.l10n.authLanguageLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final locale in localeController.enabledLocales)
                _AuthLanguageChip(
                  label: _shortLanguageLabel(locale),
                  selected:
                      ClarityLocaleCatalog.localeTagFor(locale) == selectedTag,
                  enabled: enabled,
                  onTap: () => onChanged(locale),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortLanguageLabel(Locale locale) {
    return switch (locale.languageCode) {
      'es' => 'ES',
      'en' => 'EN',
      _ => locale.languageCode.toUpperCase(),
    };
  }
}

final class _AuthLanguageChip extends StatelessWidget {
  const _AuthLanguageChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: selected ? cs.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      elevation: selected ? 0.5 : 0,
      shadowColor: cs.shadow.withValues(alpha: 0.2),
      child: InkWell(
        onTap: enabled && !selected ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.2,
              color: selected ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
