import 'package:flutter/material.dart';

import '../../data/plaid_account_service.dart';

class PlaidAccountStatusPill extends StatelessWidget {
  const PlaidAccountStatusPill({super.key, required this.status});

  final PlaidAccountConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = switch (status) {
      PlaidAccountConnectionStatus.connected => (
        bg: const Color(0xFFEAF7EF),
        fg: const Color(0xFF1B7A4C),
        border: const Color(0xFFB8DEC5),
      ),
      PlaidAccountConnectionStatus.syncing => (
        bg: const Color(0xFFECEFF5),
        fg: const Color(0xFF46566F),
        border: const Color(0xFFC7CFDC),
      ),
      PlaidAccountConnectionStatus.degraded => (
        bg: const Color(0xFFF6F0E2),
        fg: const Color(0xFF7B6234),
        border: const Color(0xFFE1D3B5),
      ),
      PlaidAccountConnectionStatus.disconnected => (
        bg: const Color(0xFFEDEBE7),
        fg: const Color(0xFF5E5A52),
        border: const Color(0xFFD6D1C8),
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
