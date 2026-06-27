import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../data/plaid_account_service.dart';
import 'plaid_account_detail_chip.dart';
import 'plaid_account_header.dart';

class PlaidAccountTile extends StatelessWidget {
  const PlaidAccountTile({
    super.key,
    required this.item,
    required this.status,
    required this.lastSyncedAt,
    required this.onResync,
    required this.onDisconnect,
    required this.onTap,
    this.webhookLastReceivedAt,
  });

  final AccountOverviewItem item;
  final PlaidAccountConnectionStatus status;
  final DateTime? lastSyncedAt;
  final DateTime? webhookLastReceivedAt;
  final VoidCallback onResync;
  final VoidCallback onDisconnect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final account = item.account;
    final balance = item.displayBalanceAmount;
    final availableBalance = account.plaidAvailableBalance;
    final showAvailable =
        availableBalance != null &&
        (balance == null || (availableBalance - balance).abs() > 0.01);
    final hasMonthlyActivity =
        item.incomeThisMonth != 0 || item.spentThisMonth != 0;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            children: [
              PlaidAccountHeader(
                item: item,
                status: status,
                lastSyncedAt: lastSyncedAt,
                webhookLastReceivedAt: webhookLastReceivedAt,
                onResync: onResync,
                onDisconnect: onDisconnect,
              ),
              if (showAvailable || hasMonthlyActivity) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      if (showAvailable)
                        PlaidAccountDetailChip(
                          label: 'Available',
                          value: formatMoney(availableBalance),
                        ),
                      if (hasMonthlyActivity)
                        PlaidAccountDetailChip(
                          label: 'This month',
                          value:
                              '${formatMoney(item.incomeThisMonth)} in / ${formatMoney(item.spentThisMonth)} out',
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
