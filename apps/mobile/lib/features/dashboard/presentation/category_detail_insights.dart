import 'package:flutter/material.dart';

import '../../../core/formatting/formatting.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/clarity_colors.dart';
import '../../budgets/domain/budget_models.dart';
import '../domain/category_month_detail.dart';
import 'category_detail_panel.dart';

/// Headline number for a category month, plus how it compares.
class CategoryDetailSummaryCard extends StatelessWidget {
  const CategoryDetailSummaryCard({
    required this.detail,
    required this.budget,
    super.key,
  });

  final CategoryMonthDetail detail;
  final BudgetCategoryPerformance? budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return CategoryDetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.categoryDetailSpentThisMonth,
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.38),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(detail.spent),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail.transactionCount == 1
                ? l10n.commonTransactionCountOne
                : l10n.commonTransactionCount(detail.transactionCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 16),
          _InsightLine(text: _comparisonText(l10n)),
          _InsightLine(
            text: l10n.categoryDetailShareOfSpending(
              formatPercent(detail.shareOfMonthSpend),
            ),
          ),
          _InsightLine(
            text: l10n.categoryDetailAverageTransaction(
              formatMoney(detail.averageTransaction),
            ),
          ),
          if (budget case final budget?)
            _InsightLine(
              text: budget.overspent > 0
                  ? l10n.categoryDetailOverBudget(
                      formatMoney(budget.overspent),
                      formatMoney(budget.budgeted),
                    )
                  : l10n.categoryDetailWithinBudget(
                      formatMoney(budget.remaining),
                      formatMoney(budget.budgeted),
                    ),
              color: budget.overspent > 0
                  ? ClarityColors.financeSpending
                  : null,
            ),
        ],
      ),
    );
  }

  String _comparisonText(AppLocalizations l10n) {
    if (detail.isNewThisMonth) return l10n.categoryDetailNewThisMonth;
    if (detail.lastMonthSpent <= 0) {
      return l10n.categoryDetailNoLastMonthSpending;
    }
    final change = detail.changeFromLastMonth;
    final percentChange = detail.percentChangeFromLastMonth;
    final amount = formatMoney(change.abs());
    final share = percentChange == null
        ? ''
        : ' (${formatPercent(percentChange.abs())})';
    return change >= 0
        ? l10n.categoryDetailUpFromLastMonth('$amount$share')
        : l10n.categoryDetailDownFromLastMonth('$amount$share');
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color ?? cs.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: color ?? cs.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

