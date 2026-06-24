import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/formatting/formatting.dart';
import '../../../../theme/clarity_colors.dart';
import '../../../../widgets/clarity_card.dart';

class AccountsSummaryCard extends StatelessWidget {
  const AccountsSummaryCard({super.key, required this.accounts});

  final List<AccountOverviewItem> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final netCashFlowTotal = accounts.fold<double>(
      0,
      (sum, item) => sum + item.netCashFlow,
    );
    final incomeTotal = accounts.fold<double>(
      0,
      (sum, item) => sum + item.incomeThisMonth,
    );
    final spendingTotal = accounts.fold<double>(
      0,
      (sum, item) => sum + item.spentThisMonth,
    );
    return ClarityCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      backgroundColor: cs.surfaceContainerLow,
      borderColor: cs.outlineVariant.withValues(alpha: 0.78),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${accounts.length} connected account${accounts.length == 1 ? '' : 's'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    _InlineMoneyLabel(
                      label: 'Income',
                      value: incomeTotal,
                      color: ClarityColors.financePositive,
                    ),
                    _InlineMoneyLabel(
                      label: 'Spending',
                      value: spendingTotal,
                      color: ClarityColors.financeSpending,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(netCashFlowTotal),
                textAlign: TextAlign.right,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: netCashFlowTotal >= 0
                      ? ClarityColors.financePositive
                      : ClarityColors.financeNegative,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'monthly net',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.46),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
