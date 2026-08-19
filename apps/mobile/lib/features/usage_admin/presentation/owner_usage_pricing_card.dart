import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_breakdown.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_models.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_card.dart';

class OwnerUsagePricingCard extends StatelessWidget {
  const OwnerUsagePricingCard({required this.pricing, super.key});

  final UsagePricingHelper pricing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    return ClarityCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: colors.surface.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.usageAdminPricingTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.usageAdminPricingHint,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.usageAdminCostPerActiveUser(
              formatUsageCost(l10n, pricing.costPerActiveUserCents),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.usageAdminCostPerVoiceMinute(
              formatUsageCost(l10n, pricing.costPerVoiceMinuteCents),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.usageAdminPriceFloor2x(
              formatUsageCost(l10n, pricing.priceFloor2xCents),
              formatUsageCost(l10n, pricing.pricePerUser2xCents),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.usageAdminPriceFloor3x(
              formatUsageCost(l10n, pricing.priceFloor3xCents),
              formatUsageCost(l10n, pricing.pricePerUser3xCents),
            ),
          ),
        ],
      ),
    );
  }
}
