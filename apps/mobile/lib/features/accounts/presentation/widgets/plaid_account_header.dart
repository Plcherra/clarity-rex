import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../core/models/models.dart';
import '../../data/plaid_account_service.dart';
import 'plaid_account_status_pill.dart';
import 'source_label_chip.dart';

class PlaidAccountHeader extends StatelessWidget {
  const PlaidAccountHeader({
    super.key,
    required this.item,
    required this.status,
    required this.lastSyncedAt,
    required this.onResync,
  });

  final AccountOverviewItem item;
  final PlaidAccountConnectionStatus status;
  final DateTime? lastSyncedAt;
  final VoidCallback onResync;

  @override
  Widget build(BuildContext context) {
    final account = item.account;
    return Row(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: const Color(0xFFEDE8DC),
          foregroundColor: const Color(0xFF5A533E),
          child: Icon(_accountIcon(account.type), size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _PlaidAccountTitleBlock(
            account: account,
            status: status,
            lastSyncedAt: lastSyncedAt,
          ),
        ),
        const SizedBox(width: 12),
        _PlaidAccountNetAndSync(
          netCashFlow: item.netCashFlow,
          status: status,
          onResync: onResync,
        ),
      ],
    );
  }

  IconData _accountIcon(AccountType type) {
    return switch (type) {
      AccountType.checking => Icons.account_balance_outlined,
      AccountType.savings => Icons.savings_outlined,
      AccountType.creditCard => Icons.credit_card_rounded,
    };
  }
}

class _PlaidAccountTitleBlock extends StatelessWidget {
  const _PlaidAccountTitleBlock({
    required this.account,
    required this.status,
    required this.lastSyncedAt,
  });

  final Account account;
  final PlaidAccountConnectionStatus status;
  final DateTime? lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SourceLabelChip(label: account.sourceLabel),
            PlaidAccountStatusPill(status: status),
            Text(
              _lastSyncedLabel(lastSyncedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.52),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_subtitle(account).isNotEmpty)
              Text(
                _subtitle(account),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.48),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _subtitle(Account account) {
    final institution = account.plaidInstitutionName?.trim();
    final inst = account.institution?.trim();
    final mask = account.plaidAccountMask?.trim();
    return [
      account.type.displayLabel,
      if (institution != null && institution.isNotEmpty) institution,
      if ((institution == null || institution.isEmpty) &&
          inst != null &&
          inst.isNotEmpty)
        inst,
      if (mask != null && mask.isNotEmpty) '**** $mask',
    ].join(' · ');
  }

  String _lastSyncedLabel(DateTime? value) {
    if (value == null) return 'Last synced unavailable';
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'Last synced just now';
    if (diff.inMinutes < 60) return 'Last synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last synced ${diff.inHours}h ago';
    return 'Last synced ${value.month}/${value.day}/${value.year}';
  }
}

class _PlaidAccountNetAndSync extends StatelessWidget {
  const _PlaidAccountNetAndSync({
    required this.netCashFlow,
    required this.status,
    required this.onResync,
  });

  final double netCashFlow;
  final PlaidAccountConnectionStatus status;
  final VoidCallback onResync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMoney(netCashFlow),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: netCashFlow > 0
                    ? const Color(0xFF1B7A4C)
                    : netCashFlow < 0
                    ? const Color(0xFFC41E3A)
                    : cs.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: status == PlaidAccountConnectionStatus.syncing
                  ? 'Syncing'
                  : 'Resync',
              onPressed: status == PlaidAccountConnectionStatus.syncing
                  ? null
                  : onResync,
              icon: status == PlaidAccountConnectionStatus.syncing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'monthly net',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.46),
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.34),
            ),
          ],
        ),
      ],
    );
  }
}
