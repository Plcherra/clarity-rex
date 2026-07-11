import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/clarity_breakpoints.dart';
import '../../core/l10n/app_l10n.dart';
import '../../theme/clarity_colors.dart';
import '../../widgets/clarity_card.dart';
import '../accountability/application/accountability_controller.dart';
import '../accountability/data/accountability_models.dart';
import '../chat/presentation/pages/conversation_list_page.dart';
import '../memory/application/memory_controller.dart';
import '../presentation/rex_ui_tokens.dart';

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

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(memoryProvider.notifier).loadSavedOverview(),
          ref.read(accountabilityProvider.notifier).loadOverview(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            l10n.assistantOverviewTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.assistantOverviewSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (!wide) ...[
            FilledButton.tonalIcon(
              onPressed: _openChats,
              icon: const Icon(Icons.forum_outlined),
              label: Text(l10n.assistantOverviewBrowseChats),
            ),
            const SizedBox(height: 16),
          ],
          _OverviewSection(
            title: l10n.assistantOverviewAttentionTitle,
            child: attention.isEmpty
                ? _OverviewEmpty(text: l10n.assistantOverviewAttentionEmpty)
                : Column(
                    children: [
                      for (final signal in attention.take(5)) ...[
                        _OverviewLine(
                          title: signal.title,
                          subtitle: signal.summary.isNotEmpty
                              ? signal.summary
                              : signal.reason,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _OverviewSection(
            title: l10n.assistantOverviewRulesTitle,
            actionLabel: l10n.assistantTabKnows,
            onAction: widget.onOpenKnows,
            child: ruleLines.isEmpty
                ? _OverviewEmpty(text: l10n.assistantOverviewRulesEmpty)
                : Column(
                    children: [
                      for (final rule in ruleLines.take(5)) ...[
                        _OverviewLine(
                          title: rule.title,
                          subtitle: rule.subtitle,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _OverviewSection(
            title: l10n.assistantOverviewThreadsTitle,
            actionLabel: l10n.assistantTabGoals,
            onAction: widget.onOpenGoals,
            child: threads.isEmpty
                ? _OverviewEmpty(text: l10n.assistantOverviewThreadsEmpty)
                : Column(
                    children: [
                      for (final thread in threads.take(5)) ...[
                        _OverviewLine(
                          title: thread.title,
                          subtitle: thread.summary ?? thread.status,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _OverviewSection(
            title: l10n.assistantOverviewGoalsTitle,
            actionLabel: l10n.assistantTabGoals,
            onAction: widget.onOpenGoals,
            child: plans.isEmpty
                ? _OverviewEmpty(text: l10n.assistantOverviewGoalsEmpty)
                : Column(
                    children: [
                      for (final plan in plans.take(5)) ...[
                        _OverviewLine(
                          title: plan.title,
                          subtitle: plan.description ??
                              plan.desiredOutcome ??
                              plan.status,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClarityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: RexUiTokens.space12),
          child,
        ],
      ),
    );
  }
}

class _OverviewLine extends StatelessWidget {
  const _OverviewLine({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

class _OverviewEmpty extends StatelessWidget {
  const _OverviewEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: context.clarityColors.textSecondary,
        height: 1.35,
      ),
    );
  }
}
