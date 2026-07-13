part of 'budgets_screen.dart';

class _BudgetSummaryStrip extends StatelessWidget {
  const _BudgetSummaryStrip({required this.metrics});

  final BudgetsPresentationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return ClarityCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.24),
      borderColor: cs.outline.withValues(alpha: 0.18),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: l10n.commonBudgeted,
              value: formatMoney(metrics.performance.totalBudgeted),
              valueColor: cs.onSurface,
              alignment: CrossAxisAlignment.start,
            ),
          ),
          _SummaryDivider(color: cs.outline.withValues(alpha: 0.10)),
          Expanded(
            child: _SummaryMetric(
              label: l10n.commonSpent,
              value: formatMoney(metrics.performance.totalSpent),
              valueColor: cs.onSurface,
              alignment: CrossAxisAlignment.center,
            ),
          ),
          _SummaryDivider(color: cs.outline.withValues(alpha: 0.10)),
          Expanded(
            child: _SummaryMetric(
              label: metrics.totalOver > 0 ? l10n.commonOver : l10n.commonLeft,
              value: metrics.totalOver > 0
                  ? formatMoney(metrics.totalOver)
                  : formatMoney(metrics.totalRemaining),
              valueColor: metrics.totalOver > 0
                  ? ClarityColors.financeNegative
                  : ClarityColors.financePositive,
              alignment: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: color);
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.alignment,
  });

  final String label;
  final String value;
  final Color valueColor;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.54),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
