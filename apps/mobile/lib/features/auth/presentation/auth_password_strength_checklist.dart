import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_colors.dart';
import '../application/auth_password_strength.dart';

/// Live create-account checklist. Sign in must not mount this.
final class AuthPasswordStrengthChecklist extends StatelessWidget {
  const AuthPasswordStrengthChecklist({
    super.key,
    required this.strength,
  });

  final AuthPasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const Key('authPasswordStrengthChecklist'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        _AuthPasswordRuleRow(
          ruleKey: 'authPasswordRuleLength',
          label: l10n.authPasswordRuleLength,
          met: strength.hasMinLength,
        ),
        _AuthPasswordRuleRow(
          ruleKey: 'authPasswordRuleLowercase',
          label: l10n.authPasswordRuleLowercase,
          met: strength.hasLowercase,
        ),
        _AuthPasswordRuleRow(
          ruleKey: 'authPasswordRuleUppercase',
          label: l10n.authPasswordRuleUppercase,
          met: strength.hasUppercase,
        ),
        _AuthPasswordRuleRow(
          ruleKey: 'authPasswordRuleDigit',
          label: l10n.authPasswordRuleDigit,
          met: strength.hasDigit,
        ),
      ],
    );
  }
}

final class _AuthPasswordRuleRow extends StatelessWidget {
  const _AuthPasswordRuleRow({
    required this.ruleKey,
    required this.label,
    required this.met,
  });

  final String ruleKey;
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final color = met ? ClarityColors.financePositive : muted;
    return Padding(
      key: Key(ruleKey),
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: met ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
