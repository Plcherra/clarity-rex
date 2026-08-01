import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/formatting.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/accountability/domain/goal_deadline_progress.dart';
import 'package:clarity/rex/accountability/domain/goal_money_pressure.dart';
import 'package:clarity/rex/accountability/presentation/accountability_display_helpers.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/core/layout/clarity_adaptive_overlay.dart';
import 'package:clarity/core/layout/clarity_breakpoints.dart';
import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/theme/clarity_sheet_insets.dart';
import 'package:clarity/widgets/clarity_celebration_burst.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

part 'accountability_page_deadline_bar.dart';
part 'accountability_page_goal_actions.dart';
part 'accountability_page_money_pressure.dart';
part 'accountability_page_sections.dart';
part 'accountability_page_shared.dart';
part 'accountability_page_steps.dart';
part 'accountability_page_tiles.dart';
part 'accountability_page_detail_sheets.dart';

class AccountabilityPage extends ConsumerStatefulWidget {
  const AccountabilityPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<AccountabilityPage> createState() => _AccountabilityPageState();
}

class _AccountabilityPageState extends ConsumerState<AccountabilityPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(accountabilityProvider.notifier).loadOverview(),
    );
  }

  Future<void> _refresh() {
    return ref.read(accountabilityProvider.notifier).loadOverview();
  }

  Future<void> _createPlan() async {
    final l10n = context.l10n;
    final result = await showDialog<_GoalFormResult>(
      context: context,
      builder: (context) => _GoalFormDialog(
        title: l10n.accountabilityAddGoalTitle,
        primaryLabel: l10n.accountabilityAddGoalPrimaryLabel,
        detailLabel: l10n.accountabilityDetailNotesHint,
        primaryHint: l10n.accountabilityAddGoalPrimaryHint,
        detailHint: l10n.accountabilityAddGoalDetailHint,
        requireDueDate: true,
        askForAmount: true,
      ),
    );
    if (result == null || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .createPlan(
          title: result.primary,
          description: result.detail,
          targetDate: result.dueDate,
          targetAmount: result.targetAmount,
        );
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityGoalSaved : null);
  }

  Future<void> _createOpenThread() async {
    final l10n = context.l10n;
    final result = await showDialog<_GoalFormResult>(
      context: context,
      builder: (context) => _GoalFormDialog(
        title: l10n.accountabilityAddOpenThreadTitle,
        primaryLabel: l10n.accountabilityAddOpenThreadPrimaryLabel,
        detailLabel: l10n.accountabilityDetailNotesHint,
        primaryHint: l10n.accountabilityAddOpenThreadPrimaryHint,
        detailHint: l10n.accountabilityAddOpenThreadDetailHint,
      ),
    );
    if (result == null || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .createOpenThread(
          title: result.primary,
          summary: result.detail.isEmpty ? null : result.detail,
        );
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityOpenThreadSaved : null);
  }

  Future<void> _closeOpenThread(OpenThread thread) async {
    final l10n = context.l10n;
    final confirmed = await _confirmArchive(
      title: l10n.accountabilityArchiveOpenThreadTitle,
      body: l10n.accountabilityArchiveOpenThreadBody(thread.title),
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .closeOpenThread(thread.id);
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityOpenThreadArchived : null);
  }

  Future<void> _pauseOpenThread(OpenThread thread) async {
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .pauseOpenThread(thread.id);
    if (!mounted) return;
    _showMutationResult(
      saved ? context.l10n.accountabilityOpenThreadUpdated : null,
    );
  }

  Future<void> _editOpenThread(OpenThread thread) async {
    final l10n = context.l10n;
    final result = await showDialog<_GoalFormResult>(
      context: context,
      builder: (context) => _GoalFormDialog(
        title: l10n.accountabilityDetailEditOpenThread,
        primaryLabel: l10n.accountabilityAddOpenThreadPrimaryLabel,
        detailLabel: l10n.accountabilityDetailNotesHint,
        primaryHint: l10n.accountabilityAddOpenThreadPrimaryHint,
        detailHint: l10n.accountabilityAddOpenThreadDetailHint,
        initialPrimary: thread.title,
        initialDetail: thread.summary ?? '',
      ),
    );
    if (result == null || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .updateOpenThread(
          thread.id,
          title: result.primary,
          summary: result.detail.isEmpty ? null : result.detail,
        );
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityOpenThreadUpdated : null);
  }

  Future<bool?> _confirmArchive({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showMutationResult(String? successMessage) {
    final message =
        successMessage ??
        ref.read(accountabilityProvider).errorMessage ??
        context.l10n.accountabilityUpdateFailed;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _goalsSection(AccountabilityOverview overview) {
    return _GoalsSection(
      plans: overview.activePlans,
      planHierarchy: overview.planHierarchy,
      onOpenPlan: _openPlanDetail,
      onArchivePlan: _archivePlan,
      onAddGoal: _createPlan,
      onToggleStep: _toggleStepFromTile,
      onMarkAchieved: _markPlanAchieved,
      onSetDueDate: _setPlanDueDate,
    );
  }

  Widget _openThreadsSection(AccountabilityOverview overview) {
    return _OpenThreadsSection(
      threads: overview.openThreads
          .where((thread) => thread.status == 'active')
          .toList(growable: false),
      onClose: _closeOpenThread,
      onPause: _pauseOpenThread,
      onEdit: _editOpenThread,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountabilityProvider);
    final overview = state.overview;
    final colors = context.clarityColors;

    return RexScaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(context.l10n.accountabilityPageTitle),
              actions: [
                IconButton(
                  onPressed: state.isLoading ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: context.l10n.accountabilityPageRefreshTooltip,
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        color: colors.accent,
        backgroundColor: colors.surfaceSoft,
        onRefresh: _refresh,
        child: Scrollbar(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  ClarityNativeLayout.active(context)
                      ? ClarityNativeLayout.pageGutter(context)
                      : RexUiTokens.space16,
                  RexUiTokens.space8,
                  ClarityNativeLayout.active(context)
                      ? ClarityNativeLayout.pageGutter(context)
                      : RexUiTokens.space16,
                  clarityScrollBottomClearance(context),
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (state.errorMessage != null)
                      _ErrorBanner(message: state.errorMessage!),
                    _GoalActionBar(
                      isBusy: state.isLoading,
                      onAddGoal: _createPlan,
                      onAddOpenThread: _createOpenThread,
                    ),
                    const SizedBox(height: RexUiTokens.space12),
                    if (state.isLoading && overview == null)
                      const _InitialLoading()
                    else if (overview == null || overview.isEmpty)
                      _EmptyAccountabilityState(onAddGoal: _createPlan)
                    else ...[
                      if (isClarityWideLayout(context))
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _goalsSection(overview)),
                            const SizedBox(width: RexUiTokens.space16),
                            Expanded(child: _openThreadsSection(overview)),
                          ],
                        )
                      else ...[
                        _goalsSection(overview),
                        const SizedBox(height: RexUiTokens.space16),
                        _openThreadsSection(overview),
                      ],
                      if (overview.achievedPlans.isNotEmpty) ...[
                        const SizedBox(height: RexUiTokens.space16),
                        _AchievedGoalsSection(
                          plans: overview.achievedPlans,
                          onReopen: _reopenPlan,
                        ),
                      ],
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
