import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/features/assistant/memory/application/memory_controller.dart';
import 'package:clarity/features/assistant/memory/data/memory_models.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/memory_archive_dialogs.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/memory_edit_dialogs.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/memory_page_filters.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/memory_page_header_widgets.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/memory_quick_filter.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/saved_memory_group_list.dart';
import 'package:clarity/features/assistant/presentation/rex_surfaces.dart';
import 'package:clarity/features/assistant/presentation/rex_ui_tokens.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  late final TextEditingController _searchController;
  var _searchQuery = '';
  var _quickFilter = MemoryQuickFilter.saved;

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

  Future<void> _setQuickFilter(MemoryQuickFilter filter) async {
    if (_quickFilter == filter) {
      return;
    }
    setState(() => _quickFilter = filter);
  }

  Future<void> _refresh() =>
      ref.read(memoryProvider.notifier).loadSavedOverview();

  Future<void> _editMemory(MemoryItem memory) async {
    final result = await showDialog<MemoryEditResult>(
      context: context,
      builder: (context) => MemoryEditDialog(memory: memory),
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
    final confirmed = await confirmArchiveMemory(context);
    if (!confirmed) {
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
    final result = await showDialog<StructuredEditResult>(
      context: context,
      builder: (context) => StructuredEditDialog(
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
    final result = await showDialog<StructuredEditResult>(
      context: context,
      builder: (context) => StructuredEditDialog(
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
    final result = await showDialog<StructuredEditResult>(
      context: context,
      builder: (context) => StructuredEditDialog(
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
    final result = await showDialog<StructuredEditResult>(
      context: context,
      builder: (context) => StructuredEditDialog(
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
    final confirmed = await confirmArchiveStructuredMemory(
      context,
      label: label,
    );
    if (!confirmed) {
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
    final filteredSaved = filterSavedMemory(
      state: state,
      query: _searchQuery,
      quickFilter: _quickFilter,
    );
    return RexScaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('What Rex Knows'),
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
                    MemorySearchAndFilters(
                      controller: _searchController,
                      selectedFilter: _quickFilter,
                      onFilterSelected: state.isLoading
                          ? null
                          : _setQuickFilter,
                    ),
                    const SizedBox(height: 12),
                    const SavedMemoryHeader(),
                    const SizedBox(height: 8),
                    ActiveMemoryToggle(
                      value: state.activeOnly,
                      onChanged: state.isLoading ? null : _setActiveOnly,
                    ),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: RexUiTokens.space12,
                        ),
                        child: MemoryErrorBanner(message: state.errorMessage!),
                      ),
                  ],
                ),
              ),
            ),
            if (state.isLoading && state.isSavedOverviewEmpty)
              const SliverFillRemaining(child: MemoryLoadingState())
            else if (state.isSavedOverviewEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MemoryEmptyState(activeOnly: state.activeOnly),
              )
            else if (filteredSaved.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MemoryFilteredEmptyState(),
              )
            else
              SavedMemoryGroupList(
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
}
