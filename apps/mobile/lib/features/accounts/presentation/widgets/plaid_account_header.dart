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
        if (_statusRecoveryMessage(status) case final message?) ...[
          const SizedBox(height: 5),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _statusRecoveryColor(cs, status),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
        if (_webhookFreshnessMessage(status, webhookLastReceivedAt)
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

  String? _statusRecoveryMessage(PlaidAccountConnectionStatus status) {
    return switch (status) {
      PlaidAccountConnectionStatus.connected => null,
      PlaidAccountConnectionStatus.syncing =>
        'Refreshing this bank connection now.',
      PlaidAccountConnectionStatus.degraded =>
        'Sync needs attention. Try refresh; if it still fails, reconnect this bank in Plaid.',
      PlaidAccountConnectionStatus.loginRequired =>
        'Plaid needs you to sign in again. Connect this bank again to resume sync.',
      PlaidAccountConnectionStatus.pendingExpiration =>
        'This Plaid connection may expire soon. Refresh now or reconnect if sync stops.',
      PlaidAccountConnectionStatus.disconnected =>
        'Future Plaid sync is stopped. Existing account history stays in Clarity.',
    };
  }

  Color _statusRecoveryColor(
    ColorScheme colorScheme,
    PlaidAccountConnectionStatus status,
  ) {
    return switch (status) {
      PlaidAccountConnectionStatus.connected =>
        colorScheme.onSurface.withValues(alpha: 0.52),
      PlaidAccountConnectionStatus.syncing => colorScheme.secondary,
      PlaidAccountConnectionStatus.degraded => ClarityColors.warning,
      PlaidAccountConnectionStatus.loginRequired => colorScheme.error,
      PlaidAccountConnectionStatus.pendingExpiration => ClarityColors.warning,
      PlaidAccountConnectionStatus.disconnected =>
        colorScheme.onSurface.withValues(alpha: 0.58),
    };
  }

  String? _webhookFreshnessMessage(
    PlaidAccountConnectionStatus status,
    DateTime? webhookLastReceivedAt,
  ) {
    if (status == PlaidAccountConnectionStatus.disconnected ||
        status == PlaidAccountConnectionStatus.syncing) {
      return null;
    }
    if (webhookLastReceivedAt == null) {
      return status == PlaidAccountConnectionStatus.connected
          ? null
          : 'No Plaid webhook has arrived yet. Use refresh if transactions look stale.';
    }
    final diff = DateTime.now().difference(webhookLastReceivedAt);
    if (diff.inHours < 24) {
      return null;
    }
    return 'No recent Plaid webhook. Last bank update signal was ${_relativeWebhookLabel(webhookLastReceivedAt)}.';
  }

  String _relativeWebhookLabel(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    }
    return 'just now';
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
                PlaidAccountConnectionStatus.loginRequired => 'Login required',
                PlaidAccountConnectionStatus.pendingExpiration =>
                  'Expiring soon',
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
