part of 'accountability_page.dart';

/// Cumulative money pressure across dated money goals.
///
/// Example lines: "$3,000 by Oct 1 (motorcycle)" then
/// "$4,000 by Dec 1 (motorcycle + RAM + storage)".
class _MoneyPressureCard extends StatelessWidget {
  const _MoneyPressureCard({required this.points});

  final List<GoalMoneyPressurePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.clarityColors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: RexUiTokens.space12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceSoft.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(RexUiTokens.memoryTileRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.accountabilityMoneyPressureTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final point in points) ...[
                Text(
                  l10n.accountabilityMoneyPressureLine(
                    formatMoney(point.cumulativeAmount),
                    _shortDate(point.byDate),
                    _titlesJoined(point.titles),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (point != points.last) const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _titlesJoined(List<String> titles) {
    if (titles.isEmpty) return '';
    if (titles.length == 1) return titles.first;
    if (titles.length == 2) return '${titles[0]} + ${titles[1]}';
    final head = titles.sublist(0, titles.length - 1).join(' + ');
    return '$head + ${titles.last}';
  }
}
