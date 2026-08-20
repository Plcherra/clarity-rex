import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../widgets/clarity_card.dart';
import '../../budgets/domain/budget_models.dart';
import '../../insights/domain/insight_generator.dart';
import '../../insights/domain/insight_item.dart';
import '../application/dashboard_deep_link_navigation.dart';
import '../domain/dashboard_snapshot.dart';

/// First-run "what to watch" leak sentence shown next to leftover on the
/// dashboard overview once accounts exist.
///
/// Reuses the existing [generateDashboardInsightItems] output and surfaces only
/// the single month-over-month leak sentence — no new insight API, generator,
/// or `/insights` sync. When there is no rising leak (or no accounts yet) the
/// banner renders nothing so the overview stays honest.
class DashboardLeakInsightBanner extends ConsumerWidget {
  const DashboardLeakInsightBanner({
    super.key,
    required this.snapshot,
    required this.budgetPerformance,
    required this.hasAccounts,
  });

  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
  final bool hasAccounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasAccounts) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    InsightItem? leak;
    for (final item in generateDashboardInsightItems(
      l10n: l10n,
      snapshot: snapshot,
      budgetPerformance: budgetPerformance,
    )) {
      if (item.type == InsightType.momLeak) {
        leak = item;
        break;
      }
    }
    if (leak == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final anchor = leak.anchor;

    return ClarityCard(
      margin: const EdgeInsets.only(top: 12),
      backgroundColor: cs.surfaceContainerHighest,
      onTap: anchor == null
          ? null
          : () => ref
                .read(dashboardDeepLinkRequestProvider.notifier)
                .request(anchor),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_up_rounded, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leak.title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  leak.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (anchor != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ],
      ),
    );
  }
}
