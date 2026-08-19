import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_breakdown.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_models.dart';
import 'package:clarity/theme/clarity_colors.dart';

class OwnerUsageCostMixList extends StatelessWidget {
  const OwnerUsageCostMixList({
    required this.slices,
    required this.plaid,
    this.title,
    super.key,
  });

  final List<UsageCostSlice> slices;
  final UsagePlaidLinks plaid;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final visible = slices
        .where((slice) => slice.metered || slice.eventCount > 0)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title ?? l10n.usageAdminCostMixTitle,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Text(
            l10n.usageAdminNoMeteredCost,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
          )
        else
          for (final slice in visible) ...[
            _MixRow(slice: slice),
            const SizedBox(height: 6),
          ],
        if (plaid.hasLinks) ...[
          const SizedBox(height: 4),
          Text(
            l10n.usageAdminPlaidNotMetered(plaid.itemCount, plaid.accountCount),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _MixRow extends StatelessWidget {
  const _MixRow({required this.slice});

  final UsageCostSlice slice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final percent = (slice.share * 100).toStringAsFixed(0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            usageCostSliceLabel(l10n, slice.labelKey),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          slice.metered
              ? '${formatUsageCost(l10n, slice.estimatedCostCents)} · ${l10n.usageAdminSliceShare(percent)}'
              : l10n.usageCostNotTracked,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}
