import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../widgets/clarity_text_prompt.dart';
import '../../auth/application/auth_controller.dart';

/// Deliberately loose. Whether an address exists is settled by the
/// confirmation email arriving or not, and a strict pattern here would only
/// turn away addresses that work.
final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Starts an email change and reports only what actually happened.
///
/// The address does not move until the confirmation link is opened, so every
/// message here says a link was sent — never that the email changed.
Future<void> showProfileEmailChange(
  BuildContext context, {
  required AuthController authController,
  required String currentEmail,
}) async {
  final l10n = context.l10n;
  final entered = await showClarityTextPrompt(
    context,
    title: l10n.profileEmailChangeAction,
    description: l10n.profileEmailChangeBody,
    fieldLabel: l10n.profileEmailNewLabel,
    confirmLabel: l10n.commonContinue,
    keyboardType: TextInputType.emailAddress,
    autocorrect: false,
  );

  if (entered == null || entered.isEmpty || !context.mounted) return;

  if (entered.toLowerCase() == currentEmail.trim().toLowerCase()) {
    _tell(context, l10n.profileEmailSame);
    return;
  }
  if (!_emailShape.hasMatch(entered)) {
    _tell(context, l10n.profileEmailInvalid);
    return;
  }

  final sent = await authController.requestEmailChange(entered);
  if (!context.mounted) return;
  _tell(
    context,
    sent
        ? l10n.profileEmailChangeSent
        : authController.errorMessage ?? l10n.profileEmailChangeFailed,
  );
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
