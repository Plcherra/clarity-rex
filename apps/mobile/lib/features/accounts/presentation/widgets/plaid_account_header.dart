import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../core/models/models.dart';
import '../../../../theme/clarity_colors.dart';
import '../../../../widgets/clarity_path_loader.dart';
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
    required this.onDisconnect,
  });

  final AccountOverviewItem item;
  final PlaidAccountConnectionStatus status;
  final DateTime? lastSyncedAt;
  final VoidCallback onResync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final account = item.account;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: cs.surfaceContainerHighest,
              foregroundColor: cs.onSurface.withValues(alpha: 0.78),
              child: Icon(_accountIcon(account.type), size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(child: _PlaidAccountTitleBlock(account: account)),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 56),
          child: _PlaidAccountMetaAndActions(
            account: account,
            item: item,
            status: status,
            lastSyncedAt: lastSyncedAt,
            onResync: onResync,
            onDisconnect: onDisconnect,
          ),
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
  const _PlaidAccountTitleBlock({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          account.displayName,
          maxLines: 3,
          overflow: TextOverflow.visible,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        if (account.displaySubtitle.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            account.displaySubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.48),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlaidAccountMetaAndActions extends StatelessWidget {
  const _PlaidAccountMetaAndActions({
    required this.account,
    required this.item,
    required this.status,
    required this.lastSyncedAt,
    required this.onResync,
    required this.onDisconnect,
  });

  final Account account;
  final AccountOverviewItem item;
  final PlaidAccountConnectionStatus status;
  final DateTime? lastSyncedAt;
  final VoidCallback onResync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SourceLabelChip(label: account.sourceLabel),
            PlaidAccountStatusPill(status: status),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          _lastSyncedLabel(lastSyncedAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.52),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: _PlaidAccountNetAndSync(
            netCashFlow: item.netCashFlow,
            status: status,
            onResync: onResync,
            onDisconnect: onDisconnect,
          ),
        ),
      ],
    );
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
    required this.onDisconnect,
  });

  final double netCashFlow;
  final PlaidAccountConnectionStatus status;
  final VoidCallback onResync;
  final VoidCallback onDisconnect;

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
                    ? ClarityColors.financePositive
                    : netCashFlow < 0
                    ? ClarityColors.financeNegative
                    : cs.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: switch (status) {
                PlaidAccountConnectionStatus.syncing => 'Syncing',
                PlaidAccountConnectionStatus.disconnected => 'Disconnected',
                _ => 'Resync',
              },
              onPressed:
                  status == PlaidAccountConnectionStatus.syncing ||
                      status == PlaidAccountConnectionStatus.disconnected
                  ? null
                  : onResync,
              icon: status == PlaidAccountConnectionStatus.syncing
                  ? const ClarityInlineLoader(size: 18, strokeWidth: 2)
                  : const Icon(Icons.sync_rounded, size: 19),
            ),
            if (status != PlaidAccountConnectionStatus.disconnected)
              IconButton(
                tooltip: 'Disconnect bank',
                onPressed: status == PlaidAccountConnectionStatus.syncing
                    ? null
                    : onDisconnect,
                icon: const Icon(Icons.link_off_rounded, size: 19),
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
