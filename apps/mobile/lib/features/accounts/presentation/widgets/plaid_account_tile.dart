import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../data/plaid_account_service.dart';
import 'plaid_account_detail_chip.dart';
import 'plaid_account_header.dart';
import 'plaid_recent_transactions.dart';

class PlaidAccountTile extends StatelessWidget {
  const PlaidAccountTile({
    super.key,
    required this.item,
    required this.status,
    required this.lastSyncedAt,
    required this.onResync,
    required this.onTap,
  });

  final AccountOverviewItem item;
  final PlaidAccountConnectionStatus status;
  final DateTime? lastSyncedAt;
  final VoidCallback onResync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final account = item.account;
    final balance = account.currentBalance;
    final availableBalance = account.plaidAvailableBalance;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            children: [
              PlaidAccountHeader(
                item: item,
                status: status,
                lastSyncedAt: lastSyncedAt,
                onResync: onResync,
              ),
              if (balance != null || availableBalance != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      if (balance != null)
                        PlaidAccountDetailChip(
                          label: 'Balance',
                          value: formatMoney(balance),
                        ),
                      if (availableBalance != null)
                        PlaidAccountDetailChip(
                          label: 'Available',
                          value: formatMoney(availableBalance),
                        ),
                    ],
                  ),
                ),
              ],
              PlaidRecentTransactions(transactions: item.recentTransactions),
            ],
          ),
        ),
      ),
    );
  }
}
