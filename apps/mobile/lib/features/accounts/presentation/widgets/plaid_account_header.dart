import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/models/models.dart';
import '../../../../theme/clarity_colors.dart';
import '../../../../widgets/clarity_path_loader.dart';
import '../../data/plaid_account_service.dart';
import 'plaid_account_freshness.dart';
import 'plaid_account_status_pill.dart';
import 'source_label_chip.dart';

class PlaidAccountHeader extends StatelessWidget {
  const PlaidAccountHeader({
    super.key,
    required this.item,
    required this.status,
    required this.lastSyncedAt,
    required this.webhookLastReceivedAt,
    required this.onResync,
    required this.onDisconnect,
  });

  final AccountOverviewItem item;
  final PlaidAccountConnectionStatus status;
  final DateTime? lastSyncedAt;
  final DateTime? webhookLastReceivedAt;
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
            webhookLastReceivedAt: webhookLastReceivedAt,
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
    required this.webhookLastReceivedAt,
    required this.onResync,
    required this.onDisconnect,
  });

  final Account account;
  final AccountOverviewItem item;
  final PlaidAccountConnectionStatus status;
  final DateTime? lastSyncedAt;
  final DateTime? webhookLastReceivedAt;
  final VoidCallback onResync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
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
          plaidAccountFreshnessLabel(l10n, status, lastSyncedAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.52),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (plaidAccountStatusRecoveryMessage(l10n, status)
            case final message?) ...[
          const SizedBox(height: 5),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: plaidAccountStatusRecoveryColor(cs, status),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
        if (plaidAccountWebhookFreshnessMessage(
              l10n,
              status,
              webhookLastReceivedAt,
            )
            case final message?) ...[
          const SizedBox(height: 5),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.60),
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: _PlaidAccountBalanceAndSync(
            item: item,
            status: status,
            onResync: onResync,
            onDisconnect: onDisconnect,
          ),
        ),
      ],
    );
  }
}

class _PlaidAccountBalanceAndSync extends StatelessWidget {
  const _PlaidAccountBalanceAndSync({
    required this.item,
    required this.status,
    required this.onResync,
    required this.onDisconnect,
  });

  final AccountOverviewItem item;
  final PlaidAccountConnectionStatus status;
  final VoidCallback onResync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final balance = item.displayBalanceAmount;
    final hasMonthlyActivity =
        item.account.type != AccountType.creditCard &&
        (item.incomeThisMonth != 0 ||
            item.spentThisMonth != 0 ||
            item.netCashFlow != 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          item.balanceLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.48),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              balance == null ? l10n.commonUnavailable : formatMoney(balance),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: balance == null || status.needsReconnect
                    ? cs.onSurface.withValues(alpha: 0.46)
                    : cs.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: switch (status) {
                PlaidAccountConnectionStatus.syncing =>
                  l10n.plaidAccountResyncTooltipSyncing,
                PlaidAccountConnectionStatus.loginRequired =>
                  l10n.plaidAccountResyncTooltipLoginRequired,
                PlaidAccountConnectionStatus.pendingExpiration =>
                  l10n.plaidAccountResyncTooltipExpiringSoon,
                PlaidAccountConnectionStatus.disconnected =>
                  l10n.plaidAccountResyncTooltipDisconnected,
                _ => l10n.plaidAccountResyncTooltipDefault,
              },
              onPressed:
                  status == PlaidAccountConnectionStatus.syncing ||
                      status == PlaidAccountConnectionStatus.disconnected
                  ? null
                  : onResync,
              icon: status == PlaidAccountConnectionStatus.syncing
                  ? const ClarityInlineLoader(size: 18, strokeWidth: 2)
                  : Icon(
                      status.needsReconnect
                          ? Icons.login_rounded
                          : Icons.sync_rounded,
                      size: 19,
                    ),
            ),
            if (status != PlaidAccountConnectionStatus.disconnected)
              IconButton(
                tooltip: l10n.plaidAccountDisconnectTooltip,
                onPressed: status == PlaidAccountConnectionStatus.syncing
                    ? null
                    : onDisconnect,
                icon: const Icon(Icons.link_off_rounded, size: 19),
              ),
          ],
        ),
        if (hasMonthlyActivity) ...[
          Text(
            l10n.accountTileThisMonthNet(formatMoney(item.netCashFlow)),
            style: theme.textTheme.labelSmall?.copyWith(
              color: item.netCashFlow > 0
                  ? ClarityColors.financePositive
                  : item.netCashFlow < 0
                  ? ClarityColors.financeNegative
                  : cs.onSurface.withValues(alpha: 0.46),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.accountTileViewAccount,
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
