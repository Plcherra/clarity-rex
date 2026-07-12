import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/clarity_breakpoints.dart';
import '../../core/l10n/app_l10n.dart';
import '../../theme/clarity_colors.dart';
import '../accountability/application/accountability_controller.dart';
import '../accountability/data/accountability_models.dart';
import '../chat/presentation/pages/conversation_list_page.dart';
import '../memory/application/memory_controller.dart';
import 'assistant_overview_widgets.dart';

/// Companion overview: rules, patterns, threads, and goals — not finance charts.
class AssistantOverviewPage extends ConsumerStatefulWidget {
  const AssistantOverviewPage({
    super.key,
    required this.onOpenChat,
    required this.onOpenKnows,
    required this.onOpenGoals,
  });

  final VoidCallback onOpenChat;
  final VoidCallback onOpenKnows;
  final VoidCallback onOpenGoals;

  @override
  ConsumerState<AssistantOverviewPage> createState() =>
      _AssistantOverviewPageState();
}

class _AssistantOverviewPageState extends ConsumerState<AssistantOverviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memoryProvider.notifier).loadSavedOverview();
      ref.read(accountabilityProvider.notifier).loadOverview();
    });
  }

  Future<void> _openChats() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ConversationListPage(
          showAppBar: true,
          onConversationSelected: () {
            Navigator.of(context).pop();
            widget.onOpenChat();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(memoryProvider);
    final accountability = ref.watch(accountabilityProvider);
    final overview = accountability.overview;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final wide = isClarityWideLayout(context);
    final loading = accountability.isLoading && overview == null;

    final ruleLines = overview == null
        ? memory.rules
            .where((rule) => rule.active)
            .map(
              (rule) => (
                title: rule.title,
                subtitle: rule.ruleText,
              ),
            )
            .toList(growable: false)
        : overview.activeRules
            .where((rule) => rule.active)
            .map(
              (rule) => (
                title: rule.title,
                subtitle: rule.ruleText,
              ),
            )
            .toList(growable: false);
    final threads = overview?.openThreads
            .where((thread) => thread.status == 'active')
            .toList(growable: false) ??
        const <OpenThread>[];
    final plans = overview?.activePlans ?? const <PlanRecord>[];
    final attention = <AccountabilitySignal>[
      ...?overview?.signals,
      ...?overview?.recentPatterns,
      ...?overview?.ruleRisks,
    ];

    final attentionItems = attention
        .take(5)
        .map(
          (signal) => (
            title: signal.title,
            subtitle: signal.summary.isNotEmpty
                ? signal.summary
                : (signal.reason.isNotEmpty ? signal.reason : null),
          ),
        )
        .toList(growable: false);
    final ruleItems = ruleLines.take(5).toList(growable: false);
    final threadItems = threads
        .take(5)
        .map(
          (thread) => (
            title: thread.title,
            subtitle: thread.summary ?? thread.status,
          ),
        )
        .toList(growable: false);
    final goalItems = plans
        .take(5)
        .map(
          (plan) => (
            title: plan.title,
            subtitle:
                plan.description ?? plan.desiredOutcome ?? plan.status,
          ),
        )
        .toList(growable: false);

    final attentionCard = OverviewSectionCard(
      title: l10n.assistantOverviewAttentionTitle,
      icon: Icons.visibility_outlined,
      count: attention.length,
      highlighted: attention.isNotEmpty,
      child: OverviewLineList(
        items: attentionItems,
        emptyText: l10n.assistantOverviewAttentionEmpty,
      ),
    );
    final rulesCard = OverviewSectionCard(
      title: l10n.assistantOverviewRulesTitle,
      icon: Icons.rule_folder_outlined,
      count: ruleLines.length,
      actionLabel: l10n.assistantTabKnows,
      onAction: widget.onOpenKnows,
      child: OverviewLineList(
        items: ruleItems,
        emptyText: l10n.assistantOverviewRulesEmpty,
      ),
    );
    final threadsCard = OverviewSectionCard(
      title: l10n.assistantOverviewThreadsTitle,
      icon: Icons.loop_outlined,
      count: threads.length,
      actionLabel: l10n.assistantTabGoals,
      onAction: widget.onOpenGoals,
      child: OverviewLineList(
        items: threadItems,
        emptyText: l10n.assistantOverviewThreadsEmpty,
      ),
    );
    final goalsCard = OverviewSectionCard(
      title: l10n.assistantOverviewGoalsTitle,
      icon: Icons.flag_outlined,
      count: plans.length,
      actionLabel: l10n.assistantTabGoals,
      onAction: widget.onOpenGoals,
      child: OverviewLineList(
        items: goalItems,
        emptyText: l10n.assistantOverviewGoalsEmpty,
      ),
    );

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(memoryProvider.notifier).loadSavedOverview(),
          ref.read(accountabilityProvider.notifier).loadOverview(),
        ]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 28 : 20, 8, wide ? 28 : 20, 28),
        children: [
          Text(
            l10n.assistantOverviewTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.assistantOverviewSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          if (!wide) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _openChats,
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: Text(l10n.assistantOverviewBrowseChats),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OverviewStatChip(
                  label: l10n.assistantOverviewAttentionTitle,
                  count: attention.length,
                  icon: Icons.visibility_outlined,
                  emphasized: attention.isNotEmpty,
                ),
                OverviewStatChip(
                  label: l10n.assistantOverviewRulesTitle,
                  count: ruleLines.length,
                  icon: Icons.rule_folder_outlined,
                ),
                OverviewStatChip(
                  label: l10n.assistantOverviewThreadsTitle,
                  count: threads.length,
                  icon: Icons.loop_outlined,
                ),
                OverviewStatChip(
                  label: l10n.assistantOverviewGoalsTitle,
                  count: plans.length,
                  icon: Icons.flag_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (wide)
              Column(
                children: [
                  attentionCard,
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: rulesCard),
                      const SizedBox(width: 14),
                      Expanded(child: threadsCard),
                    ],
                  ),
                  const SizedBox(height: 14),
                  goalsCard,
                ],
              )
            else ...[
              attentionCard,
              const SizedBox(height: 12),
              rulesCard,
              const SizedBox(height: 12),
              threadsCard,
              const SizedBox(height: 12),
              goalsCard,
            ],
          ],
        ],
      ),
    );
  }
}
