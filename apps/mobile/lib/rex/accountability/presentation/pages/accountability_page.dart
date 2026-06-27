import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final result = await showDialog<_GoalFormResult>(
      context: context,
      builder: (context) => const _GoalFormDialog(
        title: 'Add goal',
        primaryLabel: 'Goal title',
        detailLabel: 'Why this matters',
        primaryHint: 'Build a reliable morning routine',
        detailHint: 'Wake up at 5 AM and start the day cleanly',
      ),
    );
    if (result == null || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .createPlan(title: result.primary, description: result.detail);
    if (!mounted) return;
    _showMutationResult(saved ? 'Goal saved.' : null);
  }

  Future<void> _createCommitment() async {
    final result = await showDialog<_GoalFormResult>(
      context: context,
      builder: (context) => const _GoalFormDialog(
        title: 'Add commitment',
        primaryLabel: 'Commitment title',
        detailLabel: 'Commitment',
        primaryHint: 'Wake up at 5 AM',
        detailHint: 'Wake up at 5 AM and start my morning routine',
      ),
    );
    if (result == null || !mounted) return;
    final commitmentType = _commitmentTypeFor(result);
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .createCommitment(
          title: result.primary,
          commitmentText: result.detail.isEmpty
              ? result.primary
              : result.detail,
          commitmentType: commitmentType,
        );
    if (!mounted) return;
    _showMutationResult(saved ? 'Commitment saved.' : null);
  }

  Future<void> _completeCommitment(Commitment commitment) async {
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .completeCommitment(commitment.id);
    if (!mounted) return;
    _showMutationResult(saved ? 'Commitment completed.' : null);
  }

  Future<void> _missCommitment(Commitment commitment) async {
    final confirmed = await _confirmArchive(
      title: 'Mark missed?',
      body:
          'Mark "${commitment.title}" as missed? It will leave your active Goals list.',
      confirmLabel: 'Mark missed',
    );
    if (confirmed != true || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .missCommitment(commitment.id);
    if (!mounted) return;
    _showMutationResult(saved ? 'Commitment marked missed.' : null);
  }

  Future<void> _archiveCommitment(Commitment commitment) async {
    final confirmed = await _confirmArchive(
      title: 'Archive commitment?',
      body:
          'Archive "${commitment.title}"? It will leave your active Goals list.',
      confirmLabel: 'Archive',
    );
    if (confirmed != true || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .archiveCommitment(commitment.id);
    if (!mounted) return;
    _showMutationResult(saved ? 'Commitment archived.' : null);
  }

  Future<void> _archivePlan(PlanRecord plan) async {
    final confirmed = await _confirmArchive(
      title: 'Archive goal?',
      body: 'Archive "${plan.title}"? It will leave your active Goals list.',
      confirmLabel: 'Archive',
    );
    if (confirmed != true || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .archivePlan(plan.id);
    if (!mounted) return;
    _showMutationResult(saved ? 'Goal archived.' : null);
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
          _showMutationResult(saved ? 'Goal updated.' : null);
        }
        return saved;
      },
      onArchive: () => _archivePlan(plan),
    );
  }

  Future<void> _editCommitment(Commitment commitment) async {
    await _showCommitmentEditSheet(
      context,
      commitment: commitment,
      onSave: ({title, commitmentText, priority}) async {
        final saved =
            await ref.read(accountabilityProvider.notifier).updateCommitment(
          commitment.id,
          title: title,
          commitmentText: commitmentText,
          priority: priority,
        );
        if (mounted) {
          _showMutationResult(saved ? 'Commitment updated.' : null);
        }
        return saved;
      },
    );
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
            child: const Text('Cancel'),
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
        'Goals update failed.';
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
              title: const Text('Goals'),
              actions: [
                IconButton(
                  onPressed: state.isLoading ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh goals',
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
                    onAddCommitment: _createCommitment,
                  ),
                  const SizedBox(height: 20),
                  if (state.isLoading && overview == null)
                    const _InitialLoading()
                  else if (overview == null || overview.isEmpty)
                    _EmptyAccountabilityState(onAddGoal: _createPlan)
                  else ...[
                    _GoalsSection(
                      plans: overview.activePlans,
                      onOpenPlan: _openPlanDetail,
                      onArchivePlan: _archivePlan,
                      onAddGoal: _createPlan,
                    ),
                    const SizedBox(height: 24),
                    _CommitmentSection(
                      commitments: overview.openCommitments
                          .where(
                            (commitment) =>
                                commitment.planId == null &&
                                commitment.milestoneId == null,
                          )
                          .toList(growable: false),
                      onComplete: _completeCommitment,
                      onMissed: _missCommitment,
                      onArchive: _archiveCommitment,
                      onEdit: _editCommitment,
                    ),
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

String _commitmentTypeFor(_GoalFormResult result) {
  final text = '${result.primary} ${result.detail}'.toLowerCase();
  if (text.contains('wake') ||
      text.contains('5 am') ||
      text.contains('5:00') ||
      text.contains('morning routine')) {
    return 'habit';
  }
  return 'task';
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
  });

  final String title;
  final String primaryLabel;
  final String detailLabel;
  final String primaryHint;
  final String detailHint;

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _primaryController = TextEditingController();
  final _detailController = TextEditingController();

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
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
