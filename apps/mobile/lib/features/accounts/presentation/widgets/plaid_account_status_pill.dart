import 'package:flutter/material.dart';

import '../../data/plaid_account_service.dart';

class PlaidAccountStatusPill extends StatelessWidget {
  const PlaidAccountStatusPill({super.key, required this.status});

  final PlaidAccountConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = switch (status) {
      PlaidAccountConnectionStatus.connected => (
        bg: const Color(0xFF1B7A4C).withValues(alpha: 0.18),
        fg: const Color(0xFF1B7A4C),
        border: const Color(0xFF1B7A4C).withValues(alpha: 0.42),
      ),
      PlaidAccountConnectionStatus.syncing => (
        bg: cs.secondary.withValues(alpha: 0.16),
        fg: cs.secondary,
        border: cs.secondary.withValues(alpha: 0.38),
      ),
      PlaidAccountConnectionStatus.degraded => (
        bg: cs.primary.withValues(alpha: 0.16),
        fg: cs.primary,
        border: cs.primary.withValues(alpha: 0.38),
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
          status.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.fg,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
