import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/features/usage_admin/application/owner_usage_controller.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_filter.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_models.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_card.dart';
import 'package:clarity/widgets/clarity_diamond_loader.dart';
import 'package:clarity/widgets/clarity_usage_charts.dart';

final class OwnerUserDetailScreen extends StatefulWidget {
  const OwnerUserDetailScreen({
    required this.user,
    required this.filter,
    super.key,
    OwnerUserDetailController? controller,
  }) : _controller = controller;

  final OwnerUserUsage user;
  final UsageAdminFilter filter;
  final OwnerUserDetailController? _controller;

  @override
  State<OwnerUserDetailScreen> createState() => _OwnerUserDetailScreenState();
}

class _OwnerUserDetailScreenState extends State<OwnerUserDetailScreen> {
  late final OwnerUserDetailController _controller =
      widget._controller ??
      OwnerUserDetailController(user: widget.user, filter: widget.filter);
  late final bool _ownsController = widget._controller == null;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.user.displayLabel),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return Center(
              child: ClarityDiamondLoader(
                size: 56,
                label: l10n.usageAdminLoadingUserUsage,
              ),
            );
          }
          if (_controller.loadFailed) {
            return Center(child: Text(l10n.usageAdminUserLoadFailed));
          }

          final daily = _controller.dailyUsage?.daily ?? const [];
          final voiceValues = daily.map((row) => row.voiceSeconds).toList();
          final callValues = daily.map((row) => row.llmCalls.toDouble()).toList();
          final labels = daily
              .map((row) => shortDayLabel(l10n, row.usageDate))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              ClarityCard(
                padding: const EdgeInsets.all(18),
                backgroundColor: colors.surface.withValues(alpha: 0.72),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.usageAdminEstimatedCostPeriod,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatUsageCost(
                        l10n,
                        widget.user.monthEstimatedCostCents,
                        hasUsageWithoutCost: widget.user.monthLlmCalls > 0 ||
                            widget.user.monthVoiceSeconds > 0,
                      ),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.usageSummaryDailyVoiceMinutes,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.usageAdminDailyChartsCaption,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              VoiceUsageDailyLineChart(values: voiceValues, labels: labels),
              const SizedBox(height: 16),
              Text(
                l10n.usageSummaryDailyAiCalls,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              UsageDailyBarChart(values: callValues, labels: labels),
              const SizedBox(height: 16),
              Text(
                l10n.usageAdminUsageShape,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.usageAdminRadarChartCaption,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              UsageRadarChart(
                titles: [
                  l10n.usageAdminRadarVoiceMin,
                  l10n.usageAdminRadarChatLlm,
                  l10n.usageAdminRadarVoiceLlm,
                  l10n.usageAdminRadarSttMin,
                  l10n.usageAdminRadarTtsMin,
                ],
                values: [
                  widget.user.monthVoiceSeconds / 60,
                  widget.user.monthChatLlmCalls.toDouble(),
                  widget.user.monthVoiceLlmCalls.toDouble(),
                  widget.user.monthSttSeconds / 60,
                  widget.user.monthTtsSeconds / 60,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
