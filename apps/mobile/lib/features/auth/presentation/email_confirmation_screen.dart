import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_gradients.dart';
import '../../../widgets/clarity_button.dart';
import '../../../widgets/clarity_card.dart';
import '../application/auth_controller.dart';

final class EmailConfirmationScreen extends StatefulWidget {
  const EmailConfirmationScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

final class _EmailConfirmationScreenState extends State<EmailConfirmationScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.bindLocalizations(context.l10n);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.prepareSignInAfterEmailConfirmation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final l10n = context.l10n;
        final email = widget.controller.pendingConfirmationEmail ?? '';
        final error = widget.controller.errorMessage;
        final info = widget.controller.infoMessage;

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
                            child: Icon(
                              Icons.mark_email_unread_outlined,
                              size: 56,
                              color: cs.secondary,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            l10n.authConfirmEmailTitle,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.authConfirmEmailSubtitle(email),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.authConfirmEmailHint,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
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
                          if (info != null && info.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              info,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          ClarityButton.filled(
                            label: l10n.authConfirmEmailContinueButton,
                            onPressed: widget.controller.isLoading
                                ? null
                                : widget
                                      .controller
                                      .prepareSignInAfterEmailConfirmation,
                            expanded: true,
                          ),
                          const SizedBox(height: 12),
                          ClarityButton.text(
                            label: l10n.authConfirmEmailResendButton,
                            onPressed: widget.controller.isLoading
                                ? null
                                : widget.controller.resendConfirmationEmail,
                            expanded: true,
                          ),
                          const SizedBox(height: 4),
                          ClarityButton.text(
                            label: l10n.authConfirmEmailBackToSignIn,
                            onPressed: widget.controller.isLoading
                                ? null
                                : widget
                                      .controller
                                      .clearPendingEmailConfirmation,
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
