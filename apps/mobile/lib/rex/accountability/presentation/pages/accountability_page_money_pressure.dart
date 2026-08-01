part of 'accountability_page.dart';

/// Total dollars under the goal tiles. Per-goal amounts stay on each card only.
class _MoneyNeedsSummary extends StatelessWidget {
  const _MoneyNeedsSummary({required this.summary});

  final GoalMoneyNeedsSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.clarityColors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: RexUiTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountabilityMoneyPressureTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(summary.totalAmount),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
