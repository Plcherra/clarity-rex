import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';

import '../../../../theme/clarity_colors.dart';
import '../../data/plaid_account_service.dart';
import '../accounts_plaid_status_helpers.dart';

class PlaidAccountStatusPill extends StatelessWidget {
  const PlaidAccountStatusPill({super.key, required this.status});

  final PlaidAccountConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = switch (status) {
      PlaidAccountConnectionStatus.connected => (
        bg: ClarityColors.financePositive.withValues(alpha: 0.18),
        fg: ClarityColors.financePositive,
        border: ClarityColors.financePositive.withValues(alpha: 0.42),
      ),
      PlaidAccountConnectionStatus.syncing => (
        bg: cs.secondary.withValues(alpha: 0.16),
        fg: cs.secondary,
        border: cs.secondary.withValues(alpha: 0.38),
      ),
      PlaidAccountConnectionStatus.degraded => (
        bg: ClarityColors.warning.withValues(alpha: 0.18),
        fg: ClarityColors.warning,
        border: ClarityColors.warning.withValues(alpha: 0.42),
      ),
      PlaidAccountConnectionStatus.loginRequired => (
        bg: cs.error.withValues(alpha: 0.14),
        fg: cs.error,
        border: cs.error.withValues(alpha: 0.38),
      ),
      PlaidAccountConnectionStatus.pendingExpiration => (
        bg: ClarityColors.warning.withValues(alpha: 0.18),
        fg: ClarityColors.warning,
        border: ClarityColors.warning.withValues(alpha: 0.42),
      ),
      PlaidAccountConnectionStatus.disconnected => (
        bg: cs.surfaceContainerHighest,
        fg: cs.onSurface.withValues(alpha: 0.64),
        border: cs.outlineVariant.withValues(alpha: 0.78),
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          plaidConnectionStatusLabel(context.l10n, status),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.fg,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
