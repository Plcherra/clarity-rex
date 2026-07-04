import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/accountability/presentation/accountability_display_helpers.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

part 'accountability_page_sections.dart';
part 'accountability_page_shared.dart';
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
      ),
    );
    if (result == null || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .createPlan(title: result.primary, description: result.detail);
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityGoalSaved : null);
  }

  Future<void> _createOpenThread() async {
    final l10n = context.l10n;
    final result = await showDialog<_GoalFormResult>(
      context: context,
      builder: (context) => _GoalFormDialog(
        title: l10n.accountabilityAddCommitmentTitle,
        primaryLabel: l10n.accountabilityAddCommitmentPrimaryLabel,
        detailLabel: l10n.accountabilityDetailNotesHint,
        primaryHint: l10n.accountabilityAddCommitmentPrimaryHint,
        detailHint: l10n.accountabilityAddCommitmentDetailHint,
      ),
    );
    if (result == null || !mounted) return;
    final saved = await ref.read(accountabilityProvider.notifier).createOpenThread(
      title: result.primary,
      summary: result.detail.isEmpty ? null : result.detail,
    );
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityCommitmentSaved : null);
  }

  Future<void> _closeOpenThread(OpenThread thread) async {
    final l10n = context.l10n;
    final confirmed = await _confirmArchive(
      title: l10n.accountabilityArchiveCommitmentTitle,
      body: l10n.accountabilityArchiveCommitmentBody(thread.title),
      confirmLabel: l10n.commonArchive,
    );
    if (confirmed != true || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .closeOpenThread(thread.id);
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityCommitmentArchived : null);
  }

  Future<void> _pauseOpenThread(OpenThread thread) async {
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .pauseOpenThread(thread.id);
    if (!mounted) return;
    _showMutationResult(saved ? context.l10n.accountabilityCommitmentUpdated : null);
  }

  Future<void> _editOpenThread(OpenThread thread) async {
    final l10n = context.l10n;
    final result = await showDialog<_GoalFormResult>(
      context: context,
      builder: (context) => _GoalFormDialog(
        title: l10n.accountabilityDetailEditCommitment,
        primaryLabel: l10n.accountabilityAddCommitmentPrimaryLabel,
        detailLabel: l10n.accountabilityDetailNotesHint,
        primaryHint: l10n.accountabilityAddCommitmentPrimaryHint,
        detailHint: l10n.accountabilityAddCommitmentDetailHint,
        initialPrimary: thread.title,
        initialDetail: thread.summary ?? '',
      ),
    );
    if (result == null || !mounted) return;
    final saved = await ref.read(accountabilityProvider.notifier).updateOpenThread(
      thread.id,
      title: result.primary,
      summary: result.detail.isEmpty ? null : result.detail,
    );
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityCommitmentUpdated : null);
  }

  Future<void> _archivePlan(PlanRecord plan) async {
    final l10n = context.l10n;
    final confirmed = await _confirmArchive(
      title: l10n.accountabilityArchiveGoalTitle,
      body: l10n.accountabilityArchiveGoalBody(plan.title),
      confirmLabel: l10n.commonArchive,
    );
    if (confirmed != true || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .archivePlan(plan.id);
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityGoalArchived : null);
  }

  Future<void> _openPlanDetail(PlanRecord plan) async {
    await _showPlanDetailSheet(
      context,
      plan: plan,
      onSave: ({
        title,
        description,
        priority,
        status,
        targetDate,
      }) async {
        final saved = await ref.read(accountabilityProvider.notifier).updatePlan(
          plan.id,
          title: title,
          description: description,
          priority: priority,
          status: status,
          targetDateIso: targetDate?.toUtc().toIso8601String(),
        );
        if (mounted) {
          _showMutationResult(saved ? context.l10n.accountabilityGoalUpdated : null);
        }
        return saved;
      },
      onArchive: () => _archivePlan(plan),
    );
  }

  Future<void> _archivePlan(PlanRecord plan) async {
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
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                RexUiTokens.space16,
                RexUiTokens.space8,
                RexUiTokens.space16,
                RexUiTokens.space24,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (state.errorMessage != null)
                    _ErrorBanner(message: state.errorMessage!),
                  _GoalActionBar(
                    isBusy: state.isLoading,
                    onAddGoal: _createPlan,
                    onAddCommitment: _createOpenThread,
                  ),
                  const SizedBox(height: 20),
                  if (state.isLoading && overview == null)
                    const _InitialLoading()
                  else if (overview == null ||
                      (overview.isEmpty && !overview.hasInsightSignals))
                    _EmptyAccountabilityState(onAddGoal: _createPlan)
                  else ...[
                    if (overview.hasInsightSignals) ...[
                      _AccountabilityInsightsSection(overview: overview),
                      const SizedBox(height: 24),
                    ],
                    if (!overview.isEmpty) ...[
                      _GoalsSection(
                      plans: overview.activePlans,
                      onOpenPlan: _openPlanDetail,
                      onArchivePlan: _archivePlan,
                      onAddGoal: _createPlan,
                    ),
                    const SizedBox(height: 24),
                    _OpenThreadsSection(
                      threads: overview.openThreads
                          .where((thread) => thread.status == 'active')
                          .toList(growable: false),
                      onClose: _closeOpenThread,
                      onPause: _pauseOpenThread,
                      onEdit: _editOpenThread,
                    ),
                    ],
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalFormResult {
  const _GoalFormResult({required this.primary, required this.detail});

  final String primary;
  final String detail;
}

class _GoalFormDialog extends StatefulWidget {
  const _GoalFormDialog({
    required this.title,
    required this.primaryLabel,
    required this.detailLabel,
    required this.primaryHint,
    required this.detailHint,
    this.initialPrimary = '',
    this.initialDetail = '',
  });

  final String title;
  final String primaryLabel;
  final String detailLabel;
  final String primaryHint;
  final String detailHint;
  final String initialPrimary;
  final String initialDetail;

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  late final TextEditingController _primaryController;
  late final TextEditingController _detailController;

  @override
  void initState() {
    super.initState();
    _primaryController = TextEditingController(text: widget.initialPrimary);
    _detailController = TextEditingController(text: widget.initialDetail);
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _submit() {
    final primary = _primaryController.text.trim();
    if (primary.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _GoalFormResult(primary: primary, detail: _detailController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _primaryController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: widget.primaryLabel,
              hintText: widget.primaryHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: widget.detailLabel,
              hintText: widget.detailHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.commonSave)),
      ],
    );
  }
}
