import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/models/models.dart';
import '../../../dashboard/domain/account_balance_breakdown.dart';
import '../../data/plaid_account_service.dart';
import '../credit_card_month_copy.dart';
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final account = item.account;
    final balance = item.displayBalanceAmount;
    final availableBalance = account.plaidAvailableBalance;
    final remainingCredit = creditRemainingForAccount(
      account,
      owed: balance,
    );
    final isCreditCard = isCreditCardAccount(account);
    final creditLimit = account.plaidCreditLimit;
    final showCreditLeft = isCreditCard && remainingCredit != null;
    final showLimit = isCreditCard && creditLimit != null;
    final showDepositoryAvailable =
        !isCreditCard &&
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
        mouseCursor: SystemMouseCursors.click,
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
              if (showCreditLeft ||
                  showLimit ||
                  showDepositoryAvailable ||
                  hasMonthlyActivity) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      if (showLimit)
                        PlaidAccountDetailChip(
                          label: l10n.plaidAccountLimitLabel,
                          value: formatMoney(creditLimit),
                        ),
                      if (showCreditLeft)
                        PlaidAccountDetailChip(
                          label: l10n.plaidAccountCreditAvailableLabel,
                          value: formatMoney(remainingCredit),
                        ),
                      if (showDepositoryAvailable)
                        PlaidAccountDetailChip(
                          label: l10n.plaidAccountAvailableLabel,
                          value: formatMoney(availableBalance),
                        ),
                      if (hasMonthlyActivity)
                        PlaidAccountDetailChip(
                          label: l10n.plaidAccountThisMonthLabel,
                          value: isCreditCard
                              ? creditCardMonthActivityValue(
                                  l10n: l10n,
                                  payments: item.incomeThisMonth,
                                  charged: item.spentThisMonth,
                                )
                              : l10n.plaidAccountInOutSummary(
                                  formatMoney(item.incomeThisMonth),
                                  formatMoney(item.spentThisMonth),
                                ),
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
