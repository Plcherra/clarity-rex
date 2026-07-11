import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/clarity_breakpoints.dart';
import '../../../core/layout/finance_content_constraints.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../dashboard/application/dashboard_deep_link_navigation.dart';
import '../../../theme/clarity_colors.dart';
import '../../../widgets/clarity_card.dart';
import '../application/insights_controller.dart';
import '../domain/insight_item.dart';

class InsightsFeedScreen extends ConsumerStatefulWidget {
  const InsightsFeedScreen({
    super.key,
    this.liveItems = const <InsightItem>[],
  });

  /// Live dashboard signals (same source as "What to watch").
  final List<InsightItem> liveItems;

  @override
  ConsumerState<InsightsFeedScreen> createState() => _InsightsFeedScreenState();
}

class _InsightsFeedScreenState extends ConsumerState<InsightsFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(insightsProvider.notifier).load(syncFirst: true);
    });
  }

  void _openDashboardAnchor(InsightItem item) {
    final anchor = item.anchor;
    if (anchor == null) return;
    ref.read(dashboardDeepLinkRequestProvider.notifier).request(anchor);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insightsProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final liveItems = widget.liveItems;
    final savedItems = state.items;
    // Only nudge opt-in when there is nothing useful live and sync was skipped.
    final showOptInBanner =
        liveItems.isEmpty &&
        state.syncSkipped &&
        state.syncReason == 'opt_in_required' &&
        !state.storageUnavailable;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(l10n.insightsFeedTitle),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ShellContentConstraints(
        maxWidth: clarityFinanceContentMaxWidth,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(insightsProvider.notifier).load(syncFirst: true),
          child: state.isLoading && liveItems.isEmpty && savedItems.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.4,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    if (state.storageUnavailable) ...[
                      _InsightsBanner(
                        message: l10n.insightsStorageUnavailable,
                        tone: _InsightsBannerTone.info,
                      ),
                      const SizedBox(height: 12),
                    ] else if (state.errorMessage != null) ...[
                      _InsightsBanner(
                        message: state.errorMessage!,
                        tone: _InsightsBannerTone.error,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showOptInBanner) ...[
                      _InsightsBanner(
                        message: l10n.insightsOptInRequired,
                        tone: _InsightsBannerTone.info,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      l10n.insightsCurrentSection,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (liveItems.isEmpty)
                      _InsightsEmptyState(message: l10n.insightsFeedEmpty)
                    else
                      for (final item in liveItems) ...[
                        _InsightBriefingCard(
                          item: item,
                          onReviewDashboard: item.anchor == null
                              ? null
                              : () => _openDashboardAnchor(item),
                        ),
                        const SizedBox(height: 12),
                      ],
                    const SizedBox(height: 18),
                    Text(
                      l10n.insightsSavedSection,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (savedItems.isEmpty)
                      _InsightsEmptyState(message: l10n.insightsSavedEmpty)
                    else
                      for (final item in savedItems) ...[
                        _InsightBriefingCard(
                          item: item,
                          onTap: () async {
                            await ref
                                .read(insightsProvider.notifier)
                                .markRead(item);
                          },
                          onReviewDashboard: item.anchor == null
                              ? null
                              : () => _openDashboardAnchor(item),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
        ),
      ),
    );
  }
}

enum _InsightsBannerTone { info, error }

class _InsightsBanner extends StatelessWidget {
  const _InsightsBanner({required this.message, required this.tone});

  final String message;
  final _InsightsBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final background = tone == _InsightsBannerTone.error
        ? colors.financeNegative.withValues(alpha: 0.12)
        : colors.cardFill;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
      ),
    );
  }
}

class _InsightsEmptyState extends StatelessWidget {
  const _InsightsEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 36,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightBriefingCard extends StatelessWidget {
  const _InsightBriefingCard({
    required this.item,
    this.onTap,
    this.onReviewDashboard,
  });

  final InsightItem item;
  final VoidCallback? onTap;
  final VoidCallback? onReviewDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final typeLabel = _typeLabel(l10n, item.type);
    final guidance = _guidance(l10n, item.type);

    return ClarityCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.isUnread && item.id != null)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  typeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.body,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            guidance,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          if (onReviewDashboard != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onReviewDashboard,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.insightsReviewDashboard),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, InsightType type) {
    return switch (type) {
      InsightType.momLeak => l10n.insightsTypeSpendingPressure,
      InsightType.budgetOverspend => l10n.insightsTypeBudgetOver,
      InsightType.netCashFlow => l10n.insightsTypeCashFlow,
      InsightType.accountabilitySignal => l10n.insightsTypeAccountability,
    };
  }

  String _guidance(AppLocalizations l10n, InsightType type) {
    return switch (type) {
      InsightType.momLeak => l10n.insightsGuidanceSpendingPressure,
      InsightType.budgetOverspend => l10n.insightsGuidanceBudgetOver,
      InsightType.netCashFlow => l10n.insightsGuidanceCashFlow,
      InsightType.accountabilitySignal => l10n.insightsGuidanceAccountability,
    };
  }
}
