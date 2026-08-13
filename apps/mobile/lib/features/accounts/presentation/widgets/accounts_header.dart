import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../core/layout/clarity_breakpoints.dart';
import '../../../../core/layout/clarity_native_layout.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../theme/clarity_colors.dart';
import '../../../../widgets/clarity_card.dart';
import '../../../dashboard/domain/account_balance_breakdown.dart';

class AccountsSummaryCard extends StatelessWidget {
  const AccountsSummaryCard({super.key, required this.accounts});

  final List<AccountOverviewItem> accounts;

  double? get _totalSignedBalance {
    return accounts.fold<double?>(null, (sum, item) {
      final balance = item.signedBalance;
      if (balance == null) return sum;
      return (sum ?? 0) + balance;
    });
  }

  AccountBalanceBreakdown get _position {
    return buildAccountBalanceBreakdown(
      accounts: [for (final item in accounts) item.account],
      signedBalanceFor: (account) {
        for (final item in accounts) {
          if (item.account.id == account.id) return item.signedBalance;
        }
        return signedBalanceFromCurrent(account);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = context.clarityColors;
    final totalBalance = _totalSignedBalance;
    final incomeTotal = accounts.fold<double>(
      0,
      (sum, item) => sum + item.incomeThisMonth,
    );
    final spendingTotal = accounts.fold<double>(
      0,
      (sum, item) => sum + item.spentThisMonth,
    );
    final netCashFlowTotal = incomeTotal - spendingTotal;
    final position = _position;
    final l10n = context.l10n;
    final native = ClarityNativeLayout.active(context);
    return ClarityCard(
      padding: native
          ? ClarityNativeLayout.cardPadding(context)
          : const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: native
          ? BorderRadius.circular(ClarityNativeLayout.cardRadius(context))
          : null,
      backgroundColor: colors.surface.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.accountsSummaryTotalBalance,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalBalance == null
                          ? l10n.commonUnavailable
                          : formatMoney(totalBalance),
                      style: (!isClarityDesktopLayout(context)
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.headlineSmall)
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: totalBalance == null
                            ? cs.onSurface.withValues(alpha: 0.46)
                            : totalBalance >= 0
                            ? colors.financePositive
                            : colors.financeNegative,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.dashboardOverviewNetBalanceHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.56),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.commonConnectedAccountCount(
                        accounts.length,
                        accounts.length == 1 ? '' : 's',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.56),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _InlineMoneyLabel(
                label: l10n.dashboardOverviewCashTotal,
                value: position.cashTotal,
                color: colors.financePositive,
              ),
              if (position.debtTotal > 0.005)
                _InlineMoneyLabel(
                  label: l10n.dashboardOverviewDebtTotal,
                  value: position.debtTotal,
                  color: colors.financeNegative,
                ),
              if (position.creditAvailableTotal != null)
                _InlineMoneyLabel(
                  label: l10n.dashboardOverviewCreditAvailable,
                  value: position.creditAvailableTotal!,
                  color: cs.onSurface,
                ),
            ],
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.commonThisMonth,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.48),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _InlineMoneyLabel(
                        label: l10n.commonIncome,
                        value: incomeTotal,
                        color: colors.financePositive,
                      ),
                      _InlineMoneyLabel(
                        label: l10n.commonSpending,
                        value: spendingTotal,
                        color: colors.financeSpending,
                      ),
                      _InlineMoneyLabel(
                        label: l10n.dashboardOverviewLeftThisMonth,
                        value: netCashFlowTotal,
                        color: netCashFlowTotal >= 0
                            ? colors.financePositive
                            : colors.financeNegative,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dashboardOverviewActivityNotBalanceNote,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMoneyLabel extends StatelessWidget {
  const _InlineMoneyLabel({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Text.rich(
      TextSpan(
        text: '$label ',
        children: [
          TextSpan(
            text: formatMoney(value),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.56),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
