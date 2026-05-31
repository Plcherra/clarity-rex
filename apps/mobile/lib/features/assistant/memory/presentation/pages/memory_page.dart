import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/features/assistant/memory/application/memory_controller.dart';
import 'package:clarity/features/assistant/memory/data/memory_models.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  late final TextEditingController _searchController;
  var _searchQuery = '';
  var _quickFilter = _MemoryQuickFilter.saved;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
    Future.microtask(
      () => ref.read(memoryProvider.notifier).loadSavedOverview(),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
  }

  Future<void> _setActiveOnly(bool activeOnly) async {
    await ref
        .read(memoryProvider.notifier)
        .loadSavedOverview(activeOnly: activeOnly);
  }

  Future<void> _setQuickFilter(_MemoryQuickFilter filter) async {
    if (_quickFilter == filter) {
      return;
    }
    setState(() => _quickFilter = filter);
    final targetMode = filter.targetMode;
    if (ref.read(memoryProvider).selectedMode != targetMode) {
      await ref.read(memoryProvider.notifier).setMode(targetMode);
    }
  }

  Future<void> _refresh() {
    final state = ref.read(memoryProvider);
    if (state.selectedMode == MemoryReviewMode.pending) {
      return ref.read(memoryProvider.notifier).loadPendingCandidates();
    }
    return ref.read(memoryProvider.notifier).loadSavedOverview();
  }

  Future<void> _approvePendingCandidate(
    PendingMemoryCandidateItem candidate,
  ) async {
    final approved = await ref
        .read(memoryProvider.notifier)
        .approvePendingCandidate(candidate.id);
    if (!mounted) {
      return;
    }
    _showSnackBar(approved ? 'Memory saved' : _currentError());
  }

  Future<void> _rejectPendingCandidate(
    PendingMemoryCandidateItem candidate,
  ) async {
    final rejected = await ref
        .read(memoryProvider.notifier)
        .rejectPendingCandidate(candidate.id);
    if (!mounted) {
      return;
    }
    _showSnackBar(rejected ? 'Memory request dismissed' : _currentError());
  }

  Future<void> _editPendingCandidate(
    PendingMemoryCandidateItem candidate,
  ) async {
    final result = await showDialog<_PendingCandidateEditResult>(
      context: context,
      builder: (context) => _PendingCandidateEditDialog(candidate: candidate),
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updatePendingCandidate(
          candidate,
          proposal: result.proposal,
          reason: result.reason,
        );
    if (!mounted) {
      return;
    }
    _showSnackBar(saved ? 'Memory request updated' : _currentError());
  }

  Future<void> _editMemory(MemoryItem memory) async {
    final result = await showDialog<_MemoryEditResult>(
      context: context,
      builder: (context) => _MemoryEditDialog(memory: memory),
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updateMemory(
          memory.id,
          memoryType: result.memoryType,
          content: result.content,
          importance: result.importance,
          active: result.active,
        );
    if (!mounted) {
      return;
    }

    _showSnackBar(saved ? 'Memory updated' : _currentError());
  }

  Future<void> _archiveMemory(MemoryItem memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive memory?'),
        content: const Text(
          'Rex will stop using this memory in future conversations. It will remain in memory history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final archived = await ref
        .read(memoryProvider.notifier)
        .archiveMemory(memory.id);
    if (!mounted) {
      return;
    }

    _showSnackBar(archived ? 'Memory archived' : _currentError());
  }

  Future<void> _editPerson(PersonMemoryItem person) async {
    final result = await showDialog<_StructuredEditResult>(
      context: context,
      builder: (context) => _StructuredEditDialog(
        title: 'Edit person',
        primaryLabel: 'Name',
        primaryValue: person.displayName,
        detailLabel: 'Summary',
        detailValue: person.summary,
        extraLabel: 'Relationship',
        extraValue: person.relationship,
        aliasesValue: person.aliases.join(', '),
        importanceLabel: 'Importance',
        importance: person.importance,
        status: person.status,
        active: person.active,
      ),
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updatePerson(
          person.id,
          displayName: result.primary,
          summary: result.detail,
          relationship: result.extra,
          aliases: result.aliases,
          importance: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? 'Person updated' : _currentError());
    }
  }

  Future<void> _editRule(RuleMemoryItem rule) async {
    final result = await showDialog<_StructuredEditResult>(
      context: context,
      builder: (context) => _StructuredEditDialog(
        title: 'Edit rule',
        primaryLabel: 'Title',
        primaryValue: rule.title,
        detailLabel: 'Rule text',
        detailValue: rule.ruleText,
        extraLabel: 'Trigger keywords',
        extraValue: rule.triggerKeywords.join(', '),
        importanceLabel: 'Priority',
        importance: rule.priority,
        status: rule.status,
        active: rule.active,
      ),
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updateRule(
          rule.id,
          title: result.primary,
          ruleText: result.detail,
          triggerKeywords: result.extraList,
          priority: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? 'Rule updated' : _currentError());
    }
  }

  Future<void> _editPlan(PlanMemoryItem plan) async {
    final result = await showDialog<_StructuredEditResult>(
      context: context,
      builder: (context) => _StructuredEditDialog(
        title: 'Edit plan',
        primaryLabel: 'Title',
        primaryValue: plan.title,
        detailLabel: 'Description',
        detailValue: plan.description,
        extraLabel: 'Desired outcome',
        extraValue: plan.desiredOutcome,
        importanceLabel: 'Priority',
        importance: plan.priority,
        status: plan.status,
        active: plan.active,
      ),
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updatePlan(
          plan.id,
          title: result.primary,
          description: result.detail,
          desiredOutcome: result.extra,
          priority: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? 'Plan updated' : _currentError());
    }
  }

  Future<void> _editCommitment(CommitmentMemoryItem commitment) async {
    final result = await showDialog<_StructuredEditResult>(
      context: context,
      builder: (context) => _StructuredEditDialog(
        title: 'Edit commitment',
        primaryLabel: 'Title',
        primaryValue: commitment.title,
        detailLabel: 'Commitment',
        detailValue: commitment.commitmentText,
        importanceLabel: 'Priority',
        importance: commitment.priority,
        status: commitment.status,
        active: commitment.active,
      ),
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updateCommitment(
          commitment.id,
          title: result.primary,
          commitmentText: result.detail,
          priority: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? 'Commitment updated' : _currentError());
    }
  }

  Future<void> _archiveStructuredMemory(
    MemoryLayer layer,
    String id,
    String label,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive $label?'),
        content: Text(
          'Rex will stop using this $label as active context. It will remain in memory history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final archived = await ref
        .read(memoryProvider.notifier)
        .archiveStructuredMemory(layer, id);
    if (mounted) {
      _showSnackBar(archived ? '$label archived' : _currentError());
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _currentError() {
    return ref.read(memoryProvider).errorMessage ?? 'Memory action failed.';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filteredSaved = _filteredSavedMemory(state);
    final filteredCandidates = _filteredPendingCandidates(state);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Memory'),
              actions: [
                IconButton(
                  onPressed: state.isLoading ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh memory',
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MemorySearchAndFilters(
                      controller: _searchController,
                      selectedFilter: _quickFilter,
                      pendingCount: state.pendingCandidates.length,
                      onFilterSelected: state.isLoading
                          ? null
                          : _setQuickFilter,
                    ),
                    const SizedBox(height: 12),
                    if (state.selectedMode == MemoryReviewMode.pending)
                      _PendingReviewHeader(
                        pendingCount: state.pendingCandidates.length,
                      )
                    else ...[
                      const _SavedMemoryHeader(),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active memories only'),
                        value: state.activeOnly,
                        onChanged: state.isLoading ? null : _setActiveOnly,
                      ),
                      if (state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            state.errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ),
                    ],
                    if (state.selectedMode == MemoryReviewMode.pending &&
                        state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          state.errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (state.selectedMode == MemoryReviewMode.pending)
              if (state.isLoading && state.isPendingReviewEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.isPendingReviewEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _PendingReviewEmptyState(),
                )
              else if (filteredCandidates.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MemoryFilteredEmptyState(),
                )
              else
                _PendingCandidateList(
                  candidates: filteredCandidates,
                  isSaving: state.isSaving,
                  onApprove: _approvePendingCandidate,
                  onEdit: _editPendingCandidate,
                  onReject: _rejectPendingCandidate,
                )
            else if (state.isLoading && state.isSavedOverviewEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.isSavedOverviewEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _MemoryEmptyState(activeOnly: state.activeOnly),
              )
            else if (filteredSaved.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _MemoryFilteredEmptyState(),
              )
            else
              _SavedMemoryGroupList(
                saved: filteredSaved,
                onEditMemory: _editMemory,
                onArchiveMemory: _archiveMemory,
                onEditPerson: _editPerson,
                onEditRule: _editRule,
                onEditPlan: _editPlan,
                onEditCommitment: _editCommitment,
                onArchiveStructuredMemory: _archiveStructuredMemory,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  _SavedMemoryResults _filteredSavedMemory(MemoryState state) {
    final query = _normalizedQuery;
    final showPeopleOnly = _quickFilter == _MemoryQuickFilter.people;
    final showPreferencesOnly = _quickFilter == _MemoryQuickFilter.preferences;

    List<T> filterList<T>(Iterable<T> items, bool Function(T item) matches) {
      return items.where(matches).toList(growable: false);
    }

    final memories = showPeopleOnly
        ? const <MemoryItem>[]
        : filterList(state.memories, (memory) {
            if (showPreferencesOnly &&
                memory.memoryType != MemoryType.preference) {
              return false;
            }
            return _matchesQuery(query, [
              memory.content,
              memory.memoryType.label,
              'Importance ${memory.importance}',
            ]);
          });

    return _SavedMemoryResults(
      identity: showPreferencesOnly
          ? const []
          : memories
                .where(
                  (memory) =>
                      memory.memoryType.memoryGroup == MemoryGroup.identity,
                )
                .toList(growable: false),
      preferences: showPeopleOnly
          ? const []
          : memories
                .where(
                  (memory) =>
                      memory.memoryType.memoryGroup == MemoryGroup.preferences,
                )
                .toList(growable: false),
      people: showPreferencesOnly
          ? const []
          : filterList(
              state.people,
              (person) => _matchesQuery(query, [
                person.displayName,
                person.relationship,
                person.summary,
                person.aliases.join(' '),
                'Importance ${person.importance}',
                person.status.memoryRecordLabel,
              ]),
            ),
      rules: showPeopleOnly || showPreferencesOnly
          ? const []
          : filterList(
              state.rules,
              (rule) => _matchesQuery(query, [
                rule.title,
                rule.ruleText,
                rule.ruleType.memoryRecordLabel,
                rule.triggerKeywords.join(' '),
                'Priority ${rule.priority}',
                rule.status.memoryRecordLabel,
              ]),
            ),
      plans: showPeopleOnly || showPreferencesOnly
          ? const []
          : filterList(
              state.plans,
              (plan) => _matchesQuery(query, [
                plan.title,
                plan.description,
                plan.desiredOutcome,
                plan.planType.memoryRecordLabel,
                'Priority ${plan.priority}',
                plan.status.memoryRecordLabel,
              ]),
            ),
      commitments: showPeopleOnly || showPreferencesOnly
          ? const []
          : filterList(
              state.commitments,
              (commitment) => _matchesQuery(query, [
                commitment.title,
                commitment.commitmentText,
                commitment.commitmentType.memoryRecordLabel,
                'Priority ${commitment.priority}',
                commitment.status.memoryRecordLabel,
              ]),
            ),
      recent: showPeopleOnly || showPreferencesOnly
          ? const []
          : memories
                .where(
                  (memory) =>
                      memory.memoryType.memoryGroup == MemoryGroup.recent,
                )
                .toList(growable: false),
      other: showPeopleOnly || showPreferencesOnly
          ? const []
          : memories
                .where(
                  (memory) =>
                      memory.memoryType.memoryGroup == MemoryGroup.other,
                )
                .toList(growable: false),
    );
  }

  List<PendingMemoryCandidateItem> _filteredPendingCandidates(
    MemoryState state,
  ) {
    final query = _normalizedQuery;
    return state.pendingCandidates
        .where((candidate) {
          if (_quickFilter == _MemoryQuickFilter.corrections &&
              !candidate.isCorrection) {
            return false;
          }
          return _matchesQuery(query, [
            candidate.previewLabel,
            candidate.reasonLabel,
            candidate.candidateTypeLabel,
            candidate.riskLabel,
            candidate.statusLabel,
            candidate.expectedActionLabel,
            candidate.correctionOldValue,
            candidate.correctionNewValue,
            candidate.correctionTargetHint,
          ]);
        })
        .toList(growable: false);
  }

  String get _normalizedQuery => _searchQuery.trim().toLowerCase();
}

class _PendingReviewHeader extends StatelessWidget {
  const _PendingReviewHeader({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.fact_check_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pendingCount == 0
                        ? 'No memory requests waiting'
                        : '$pendingCount memory request${pendingCount == 1 ? '' : 's'} waiting',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rex only saves these after you approve them. Saved memories stay in the Saved view.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemorySearchAndFilters extends StatelessWidget {
  const _MemorySearchAndFilters({
    required this.controller,
    required this.selectedFilter,
    required this.pendingCount,
    required this.onFilterSelected,
  });

  final TextEditingController controller;
  final _MemoryQuickFilter selectedFilter;
  final int pendingCount;
  final ValueChanged<_MemoryQuickFilter>? onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search memory',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: controller.clear,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear search',
                  ),
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _MemoryQuickFilter.values)
              ChoiceChip(
                label: Text(filter.label(pendingCount)),
                selected: selectedFilter == filter,
                onSelected: onFilterSelected == null
                    ? null
                    : (_) => onFilterSelected!(filter),
                labelStyle: theme.textTheme.labelLarge,
              ),
          ],
        ),
      ],
    );
  }
}

class _SavedMemoryHeader extends StatelessWidget {
  const _SavedMemoryHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.psychology_alt_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved memory',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rex uses these approved memories to personalize future conversations. Pending suggestions stay separate until you approve them.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingCandidateList extends StatelessWidget {
  const _PendingCandidateList({
    required this.candidates,
    required this.isSaving,
    required this.onApprove,
    required this.onEdit,
    required this.onReject,
  });

  final List<PendingMemoryCandidateItem> candidates;
  final bool isSaving;
  final ValueChanged<PendingMemoryCandidateItem> onApprove;
  final ValueChanged<PendingMemoryCandidateItem> onEdit;
  final ValueChanged<PendingMemoryCandidateItem> onReject;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: candidates.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final candidate = candidates[index];
        return _PendingCandidateTile(
          candidate: candidate,
          isSaving: isSaving,
          onApprove: () => onApprove(candidate),
          onEdit: () => onEdit(candidate),
          onReject: () => onReject(candidate),
        );
      },
    );
  }
}

class _PendingCandidateTile extends StatelessWidget {
  const _PendingCandidateTile({
    required this.candidate,
    required this.isSaving,
    required this.onApprove,
    required this.onEdit,
    required this.onReject,
  });

  final PendingMemoryCandidateItem candidate;
  final bool isSaving;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = candidate.isHighRisk ? scheme.error : scheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.14),
        foregroundColor: accent,
        child: Icon(
          candidate.isHighRisk
              ? Icons.warning_amber_rounded
              : Icons.fact_check_outlined,
          size: 20,
        ),
      ),
      title: Text(
        candidate.previewLabel,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (candidate.isCorrection &&
                (candidate.correctionOldValue != null ||
                    candidate.correctionNewValue != null)) ...[
              if (candidate.correctionOldValue != null)
                _MemoryReviewInfoRow(
                  icon: Icons.history_rounded,
                  text: 'May change: ${candidate.correctionOldValue}',
                  color: scheme.onSurfaceVariant,
                ),
              if (candidate.correctionNewValue != null)
                _MemoryReviewInfoRow(
                  icon: Icons.update_rounded,
                  text: 'Replace with: ${candidate.correctionNewValue}',
                  color: scheme.onSurfaceVariant,
                ),
              const SizedBox(height: 8),
            ],
            if (candidate.reason?.trim().isNotEmpty == true) ...[
              Text(
                'Why Rex suggested it',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                candidate.reasonLabel!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MemoryMetaChip(label: candidate.candidateTypeLabel),
                _MemoryMetaChip(label: candidate.riskLabel),
                _MemoryMetaChip(label: candidate.statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            _MemoryReviewInfoRow(
              icon: Icons.task_alt_rounded,
              text: candidate.expectedActionLabel,
              color: scheme.onSurfaceVariant,
            ),
            if (candidate.sourceLabel != null)
              _MemoryReviewInfoRow(
                icon: Icons.chat_bubble_outline_rounded,
                text: candidate.sourceLabel!,
                color: scheme.onSurfaceVariant,
              ),
            _MemoryReviewInfoRow(
              icon: candidate.isHighRisk
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline_rounded,
              text: candidate.statusDetail,
              color: candidate.isHighRisk
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
            if (candidate.verificationMessage != null)
              _MemoryReviewInfoRow(
                icon: candidate.verificationPassed == false
                    ? Icons.error_outline_rounded
                    : Icons.verified_outlined,
                text: candidate.verificationMessage!,
                color: candidate.verificationPassed == false
                    ? scheme.error
                    : scheme.onSurfaceVariant,
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: isSaving ? null : onApprove,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    candidate.isHighRisk ? 'Confirm save' : 'Approve',
                  ),
                ),
                TextButton.icon(
                  onPressed: isSaving ? null : onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit first'),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryReviewInfoRow extends StatelessWidget {
  const _MemoryReviewInfoRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingReviewEmptyState extends StatelessWidget {
  const _PendingReviewEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt_rounded,
              color: scheme.onSurfaceVariant,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              'No pending memory review',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'When Rex notices something it should remember, it will ask here before saving it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryFilteredEmptyState extends StatelessWidget {
  const _MemoryFilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: scheme.onSurfaceVariant,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text('No matching memories', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Try a different search or choose another memory filter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedMemoryResults {
  const _SavedMemoryResults({
    required this.identity,
    required this.preferences,
    required this.people,
    required this.rules,
    required this.plans,
    required this.commitments,
    required this.recent,
    required this.other,
  });

  final List<MemoryItem> identity;
  final List<MemoryItem> preferences;
  final List<PersonMemoryItem> people;
  final List<RuleMemoryItem> rules;
  final List<PlanMemoryItem> plans;
  final List<CommitmentMemoryItem> commitments;
  final List<MemoryItem> recent;
  final List<MemoryItem> other;

  bool get isEmpty {
    return identity.isEmpty &&
        preferences.isEmpty &&
        people.isEmpty &&
        rules.isEmpty &&
        plans.isEmpty &&
        commitments.isEmpty &&
        recent.isEmpty &&
        other.isEmpty;
  }
}

class _SavedMemoryGroupList extends StatelessWidget {
  const _SavedMemoryGroupList({
    required this.saved,
    required this.onEditMemory,
    required this.onArchiveMemory,
    required this.onEditPerson,
    required this.onEditRule,
    required this.onEditPlan,
    required this.onEditCommitment,
    required this.onArchiveStructuredMemory,
  });

  final _SavedMemoryResults saved;
  final ValueChanged<MemoryItem> onEditMemory;
  final ValueChanged<MemoryItem> onArchiveMemory;
  final ValueChanged<PersonMemoryItem> onEditPerson;
  final ValueChanged<RuleMemoryItem> onEditRule;
  final ValueChanged<PlanMemoryItem> onEditPlan;
  final ValueChanged<CommitmentMemoryItem> onEditCommitment;
  final void Function(MemoryLayer layer, String id, String label)
  onArchiveStructuredMemory;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    void addGroup(MemoryGroup group, List<Widget> tiles) {
      if (tiles.isEmpty) {
        return;
      }
      children.add(_MemoryGroupHeader(group: group));
      for (final (index, tile) in tiles.indexed) {
        if (index > 0) {
          children.add(const Divider(height: 1, indent: 72));
        }
        children.add(tile);
      }
    }

    addGroup(
      MemoryGroup.identity,
      saved.identity.map(_memoryTile).toList(growable: false),
    );
    addGroup(
      MemoryGroup.preferences,
      saved.preferences.map(_memoryTile).toList(growable: false),
    );
    addGroup(
      MemoryGroup.peoplePlaces,
      saved.people
          .map(
            (person) => _PersonMemoryTile(
              person: person,
              onEdit: () => onEditPerson(person),
              onDeactivate: person.active
                  ? () => onArchiveStructuredMemory(
                      MemoryLayer.people,
                      person.id,
                      'person',
                    )
                  : null,
            ),
          )
          .toList(growable: false),
    );
    addGroup(MemoryGroup.plans, [
      ...saved.plans.map(
        (plan) => _PlanMemoryTile(
          plan: plan,
          onEdit: () => onEditPlan(plan),
          onDeactivate: plan.active
              ? () => onArchiveStructuredMemory(
                  MemoryLayer.plans,
                  plan.id,
                  'plan',
                )
              : null,
        ),
      ),
      ...saved.commitments.map(
        (commitment) => _CommitmentMemoryTile(
          commitment: commitment,
          onEdit: () => onEditCommitment(commitment),
          onDeactivate: commitment.active
              ? () => onArchiveStructuredMemory(
                  MemoryLayer.commitments,
                  commitment.id,
                  'commitment',
                )
              : null,
        ),
      ),
    ]);
    addGroup(
      MemoryGroup.rules,
      saved.rules
          .map(
            (rule) => _RuleMemoryTile(
              rule: rule,
              onEdit: () => onEditRule(rule),
              onDeactivate: rule.active
                  ? () => onArchiveStructuredMemory(
                      MemoryLayer.rules,
                      rule.id,
                      'rule',
                    )
                  : null,
            ),
          )
          .toList(growable: false),
    );
    addGroup(
      MemoryGroup.recent,
      saved.recent.map(_memoryTile).toList(growable: false),
    );
    addGroup(
      MemoryGroup.other,
      saved.other.map(_memoryTile).toList(growable: false),
    );

    return SliverList.list(children: children);
  }

  Widget _memoryTile(MemoryItem memory) {
    return _MemoryTile(
      memory: memory,
      onEdit: () => onEditMemory(memory),
      onDeactivate: memory.active ? () => onArchiveMemory(memory) : null,
    );
  }
}

class _MemoryGroupHeader extends StatelessWidget {
  const _MemoryGroupHeader({required this.group});

  final MemoryGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Text(
        group.label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({
    required this.memory,
    required this.onEdit,
    required this.onDeactivate,
  });

  final MemoryItem memory;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: memory.active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        foregroundColor: memory.active
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        child: Icon(_iconForType(memory.memoryType), size: 20),
      ),
      title: Text(memory.content),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _MemoryMetaChip(label: memory.memoryType.label),
            _MemoryMetaChip(label: 'Importance ${memory.importance}'),
            if (_savedDate(memory.updatedAt, memory.createdAt) != null)
              _MemoryMetaChip(
                label:
                    'Updated ${_shortDate(_savedDate(memory.updatedAt, memory.createdAt)!)}',
              ),
            if (!memory.active) const _MemoryMetaChip(label: 'Inactive'),
          ],
        ),
      ),
      trailing: PopupMenuButton<_MemoryAction>(
        tooltip: 'Memory actions',
        onSelected: (action) {
          switch (action) {
            case _MemoryAction.edit:
              onEdit();
            case _MemoryAction.archive:
              onDeactivate?.call();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _MemoryAction.edit,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
          if (onDeactivate != null)
            const PopupMenuItem(
              value: _MemoryAction.archive,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.visibility_off_outlined),
                title: Text('Archive'),
              ),
            ),
        ],
      ),
      onTap: onEdit,
      textColor: memory.active ? null : scheme.onSurfaceVariant,
      titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
        color: memory.active ? scheme.onSurface : scheme.onSurfaceVariant,
      ),
    );
  }

  IconData _iconForType(MemoryType type) {
    switch (type) {
      case MemoryType.fact:
        return Icons.badge_outlined;
      case MemoryType.preference:
        return Icons.tune_rounded;
      case MemoryType.event:
        return Icons.event_note_outlined;
      case MemoryType.other:
        return Icons.note_alt_outlined;
    }
  }
}

class _PersonMemoryTile extends StatelessWidget {
  const _PersonMemoryTile({
    required this.person,
    required this.onEdit,
    required this.onDeactivate,
  });

  final PersonMemoryItem person;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return _StructuredMemoryTile(
      icon: Icons.person_outline_rounded,
      active: person.active,
      title: person.displayName,
      subtitle: person.summary ?? person.relationship ?? 'Person memory',
      chips: [
        if (person.relationship != null)
          _MemoryMetaChip(label: person.relationship!.memoryRecordLabel),
        if (person.aliases.isNotEmpty)
          _MemoryMetaChip(label: 'Also ${person.aliases.join(', ')}'),
        _MemoryMetaChip(label: 'Importance ${person.importance}'),
        _MemoryMetaChip(label: person.status.memoryRecordLabel),
        if (_savedDate(person.updatedAt, person.createdAt) != null)
          _MemoryMetaChip(
            label:
                'Updated ${_shortDate(_savedDate(person.updatedAt, person.createdAt)!)}',
          ),
        if (!person.active) const _MemoryMetaChip(label: 'Inactive'),
      ],
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class _RuleMemoryTile extends StatelessWidget {
  const _RuleMemoryTile({
    required this.rule,
    required this.onEdit,
    required this.onDeactivate,
  });

  final RuleMemoryItem rule;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return _StructuredMemoryTile(
      icon: Icons.rule_rounded,
      active: rule.active,
      title: rule.title,
      subtitle: rule.ruleText,
      chips: [
        _MemoryMetaChip(label: rule.ruleType.memoryRecordLabel),
        _MemoryMetaChip(label: rule.status.memoryRecordLabel),
        _MemoryMetaChip(label: 'Priority ${rule.priority}'),
        if (_savedDate(rule.updatedAt, rule.createdAt) != null)
          _MemoryMetaChip(
            label:
                'Updated ${_shortDate(_savedDate(rule.updatedAt, rule.createdAt)!)}',
          ),
        if (rule.triggerKeywords.isNotEmpty)
          _MemoryMetaChip(label: rule.triggerKeywords.join(', ')),
        if (!rule.active) const _MemoryMetaChip(label: 'Inactive'),
      ],
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class _PlanMemoryTile extends StatelessWidget {
  const _PlanMemoryTile({
    required this.plan,
    required this.onEdit,
    required this.onDeactivate,
  });

  final PlanMemoryItem plan;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return _StructuredMemoryTile(
      icon: Icons.flag_outlined,
      active: plan.active,
      title: plan.title,
      subtitle: plan.desiredOutcome ?? plan.description ?? 'Plan memory',
      chips: [
        _MemoryMetaChip(label: plan.planType.memoryRecordLabel),
        _MemoryMetaChip(label: plan.status.memoryRecordLabel),
        _MemoryMetaChip(label: 'Priority ${plan.priority}'),
        if (plan.targetDate != null)
          _MemoryMetaChip(label: 'Target ${_shortDate(plan.targetDate!)}'),
        if (_savedDate(plan.updatedAt, plan.createdAt) != null)
          _MemoryMetaChip(
            label:
                'Updated ${_shortDate(_savedDate(plan.updatedAt, plan.createdAt)!)}',
          ),
        if (!plan.active) const _MemoryMetaChip(label: 'Inactive'),
      ],
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class _CommitmentMemoryTile extends StatelessWidget {
  const _CommitmentMemoryTile({
    required this.commitment,
    required this.onEdit,
    required this.onDeactivate,
  });

  final CommitmentMemoryItem commitment;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return _StructuredMemoryTile(
      icon: Icons.check_circle_outline_rounded,
      active: commitment.active,
      title: commitment.title,
      subtitle: commitment.commitmentText,
      chips: [
        _MemoryMetaChip(label: commitment.commitmentType.memoryRecordLabel),
        _MemoryMetaChip(label: commitment.status.memoryRecordLabel),
        _MemoryMetaChip(label: 'Priority ${commitment.priority}'),
        if (commitment.dueAt != null)
          _MemoryMetaChip(label: 'Due ${_shortDate(commitment.dueAt!)}'),
        if (_savedDate(commitment.updatedAt, commitment.createdAt) != null)
          _MemoryMetaChip(
            label:
                'Updated ${_shortDate(_savedDate(commitment.updatedAt, commitment.createdAt)!)}',
          ),
        if (!commitment.active) const _MemoryMetaChip(label: 'Inactive'),
      ],
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class _StructuredMemoryTile extends StatelessWidget {
  const _StructuredMemoryTile({
    required this.icon,
    required this.active,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.onEdit,
    required this.onDeactivate,
  });

  final IconData icon;
  final bool active;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        foregroundColor: active
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        child: Icon(icon, size: 20),
      ),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: active ? scheme.onSurfaceVariant : scheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: chips,
            ),
          ],
        ),
      ),
      textColor: active ? null : scheme.onSurfaceVariant,
      titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
        color: active ? scheme.onSurface : scheme.onSurfaceVariant,
      ),
      trailing: PopupMenuButton<_MemoryAction>(
        tooltip: 'Memory actions',
        onSelected: (action) {
          switch (action) {
            case _MemoryAction.edit:
              onEdit();
            case _MemoryAction.archive:
              onDeactivate?.call();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _MemoryAction.edit,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
          if (onDeactivate != null)
            const PopupMenuItem(
              value: _MemoryAction.archive,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.visibility_off_outlined),
                title: Text('Archive'),
              ),
            ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

class _MemoryMetaChip extends StatelessWidget {
  const _MemoryMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MemoryEmptyState extends StatelessWidget {
  const _MemoryEmptyState({required this.activeOnly});

  final bool activeOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_alt_outlined,
              color: scheme.onSurfaceVariant,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(_emptyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _emptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _emptyTitle {
    return activeOnly ? 'No active saved memory yet' : 'No saved memory found';
  }

  String get _emptyBody {
    return 'Approved facts, preferences, people, plans, rules, and recent context will appear here.';
  }
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day/${local.year}';
}

DateTime? _savedDate(DateTime? updatedAt, DateTime? createdAt) {
  return updatedAt ?? createdAt;
}

class _StructuredEditDialog extends StatefulWidget {
  const _StructuredEditDialog({
    required this.title,
    required this.primaryLabel,
    required this.primaryValue,
    required this.detailLabel,
    required this.importanceLabel,
    required this.importance,
    required this.status,
    required this.active,
    this.detailValue,
    this.extraLabel,
    this.extraValue,
    this.aliasesValue,
  });

  final String title;
  final String primaryLabel;
  final String primaryValue;
  final String detailLabel;
  final String? detailValue;
  final String? extraLabel;
  final String? extraValue;
  final String? aliasesValue;
  final String importanceLabel;
  final int importance;
  final String status;
  final bool active;

  @override
  State<_StructuredEditDialog> createState() => _StructuredEditDialogState();
}

class _StructuredEditDialogState extends State<_StructuredEditDialog> {
  late final TextEditingController _primaryController;
  late final TextEditingController _detailController;
  late final TextEditingController _extraController;
  late final TextEditingController _aliasesController;
  late final TextEditingController _statusController;
  late double _importance;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _primaryController = TextEditingController(text: widget.primaryValue);
    _detailController = TextEditingController(text: widget.detailValue ?? '');
    _extraController = TextEditingController(text: widget.extraValue ?? '');
    _aliasesController = TextEditingController(text: widget.aliasesValue ?? '');
    _statusController = TextEditingController(text: widget.status);
    _importance = widget.importance.toDouble();
    _active = widget.active;
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _detailController.dispose();
    _extraController.dispose();
    _aliasesController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _primaryController,
              decoration: InputDecoration(labelText: widget.primaryLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailController,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: widget.detailLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.extraLabel != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _extraController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: widget.extraLabel),
              ),
            ],
            if (widget.aliasesValue != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _aliasesController,
                decoration: const InputDecoration(
                  labelText: 'Aliases',
                  helperText: 'Comma-separated',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _statusController,
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(widget.importanceLabel),
                Expanded(
                  child: Slider(
                    value: _importance,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _importance.round().toString(),
                    onChanged: (value) => setState(() => _importance = value),
                  ),
                ),
                Text(_importance.round().toString()),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          ],
        ),
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

  void _submit() {
    final primary = _primaryController.text.trim();
    if (primary.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _StructuredEditResult(
        primary: primary,
        detail: _nullableText(_detailController.text),
        extra: _nullableText(_extraController.text),
        aliases: _splitCommaText(_aliasesController.text),
        importance: _importance.round(),
        status: _statusController.text.trim(),
        active: _active,
      ),
    );
  }
}

class _PendingCandidateEditDialog extends StatefulWidget {
  const _PendingCandidateEditDialog({required this.candidate});

  final PendingMemoryCandidateItem candidate;

  @override
  State<_PendingCandidateEditDialog> createState() =>
      _PendingCandidateEditDialogState();
}

class _PendingCandidateEditDialogState
    extends State<_PendingCandidateEditDialog> {
  late final TextEditingController _proposalController;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _proposalController = TextEditingController(
      text: widget.candidate.editableProposal,
    );
    _reasonController = TextEditingController(
      text: widget.candidate.reasonLabel ?? '',
    );
  }

  @override
  void dispose() {
    _proposalController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit memory request'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _proposalController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Proposed memory',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason Rex suggested it',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
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

  void _submit() {
    final proposal = _proposalController.text.trim();
    if (proposal.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _PendingCandidateEditResult(
        proposal: proposal,
        reason: _nullableText(_reasonController.text),
      ),
    );
  }
}

class _MemoryEditDialog extends StatefulWidget {
  const _MemoryEditDialog({required this.memory});

  final MemoryItem memory;

  @override
  State<_MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<_MemoryEditDialog> {
  late final TextEditingController _contentController;
  late MemoryType _memoryType;
  late double _importance;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.memory.content);
    _memoryType = widget.memory.memoryType;
    _importance = widget.memory.importance.toDouble();
    _active = widget.memory.active;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit memory'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<MemoryType>(
              initialValue: _memoryType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: MemoryType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      enabled: type != MemoryType.other,
                      child: Text(type.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _memoryType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Memory',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Importance'),
                Expanded(
                  child: Slider(
                    value: _importance,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _importance.round().toString(),
                    onChanged: (value) => setState(() => _importance = value),
                  ),
                ),
                Text(_importance.round().toString()),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          ],
        ),
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

  void _submit() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _MemoryEditResult(
        memoryType: _memoryType == MemoryType.other ? null : _memoryType,
        content: content,
        importance: _importance.round(),
        active: _active,
      ),
    );
  }
}

class _MemoryEditResult {
  const _MemoryEditResult({
    required this.memoryType,
    required this.content,
    required this.importance,
    required this.active,
  });

  final MemoryType? memoryType;
  final String content;
  final int importance;
  final bool active;
}

class _PendingCandidateEditResult {
  const _PendingCandidateEditResult({
    required this.proposal,
    required this.reason,
  });

  final String proposal;
  final String? reason;
}

enum _MemoryAction { edit, archive }

enum _MemoryQuickFilter {
  saved,
  pending,
  corrections,
  people,
  preferences;

  MemoryReviewMode get targetMode {
    switch (this) {
      case _MemoryQuickFilter.saved:
      case _MemoryQuickFilter.people:
      case _MemoryQuickFilter.preferences:
        return MemoryReviewMode.saved;
      case _MemoryQuickFilter.pending:
      case _MemoryQuickFilter.corrections:
        return MemoryReviewMode.pending;
    }
  }

  String label(int pendingCount) {
    switch (this) {
      case _MemoryQuickFilter.saved:
        return 'Saved';
      case _MemoryQuickFilter.pending:
        return pendingCount == 0 ? 'Pending' : 'Pending ($pendingCount)';
      case _MemoryQuickFilter.corrections:
        return 'Corrections';
      case _MemoryQuickFilter.people:
        return 'People';
      case _MemoryQuickFilter.preferences:
        return 'Preferences';
    }
  }
}

class _StructuredEditResult {
  const _StructuredEditResult({
    required this.primary,
    required this.importance,
    required this.status,
    required this.active,
    this.detail,
    this.extra,
    this.aliases = const [],
  });

  final String primary;
  final String? detail;
  final String? extra;
  final List<String> aliases;
  final int importance;
  final String status;
  final bool active;

  List<String> get extraList => _splitCommaText(extra ?? '');
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _splitCommaText(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

bool _matchesQuery(String query, Iterable<String?> fields) {
  if (query.isEmpty) {
    return true;
  }
  return fields.any((field) => field?.toLowerCase().contains(query) == true);
}
