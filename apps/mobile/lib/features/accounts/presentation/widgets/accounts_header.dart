import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../theme/clarity_colors.dart';
import '../../../../widgets/clarity_card.dart';

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
    return ClarityCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                      'Total balance',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalBalance == null
                          ? 'Unavailable'
                          : formatMoney(totalBalance),
                      style: theme.textTheme.headlineSmall?.copyWith(
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
                      '${accounts.length} connected account${accounts.length == 1 ? '' : 's'}',
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
                    'This month',
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
                        label: 'Income',
                        value: incomeTotal,
                        color: colors.financePositive,
                      ),
                      _InlineMoneyLabel(
                        label: 'Spending',
                        value: spendingTotal,
                        color: colors.financeSpending,
                      ),
                      _InlineMoneyLabel(
                        label: 'Net',
                        value: netCashFlowTotal,
                        color: netCashFlowTotal >= 0
                            ? colors.financePositive
                            : colors.financeNegative,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Activity this month — not the same as balance',
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
