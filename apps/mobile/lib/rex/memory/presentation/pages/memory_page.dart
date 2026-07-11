import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_l10n.dart';
import 'package:clarity/rex/memory/application/memory_controller.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_archive_dialogs.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_create_sheets.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_edit_person_sheet.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_edit_sheets.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_page_filters.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_page_header_widgets.dart';
import 'package:clarity/rex/memory/presentation/memory_l10n.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_quick_filter.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_truncation_banner.dart';
import 'package:clarity/rex/memory/presentation/widgets/saved_memory_group_list.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_sheet_insets.dart';

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
    await ref.read(memoryProvider.notifier).loadSavedOverview(
          activeOnly: activeOnly,
        );
  }

  Future<void> _setQuickFilter(MemoryQuickFilter filter) async {
    if (_quickFilter == filter) {
      return;
    }
    setState(() => _quickFilter = filter);
  }

  Future<void> _refresh() =>
      ref.read(memoryProvider.notifier).loadSavedOverview();

  Future<void> _startCreate() async {
    final kind = await showMemoryCreateTypePicker(context);
    if (kind == null || !mounted) {
      return;
    }

    final l10n = context.l10n;
    final notifier = ref.read(memoryProvider.notifier);
    var saved = false;
    String successMessage = l10n.memoryPageMemoryCreated;

    switch (kind) {
      case MemoryCreateKind.fact:
      case MemoryCreateKind.preference:
        final result = await showFlatMemoryCreateSheet(context, kind: kind);
        if (result == null) {
          return;
        }
        saved = await notifier.createMemory(
          memoryType: result.memoryType,
          content: result.content,
          importance: result.importance,
          memoryCategory: result.memoryCategory,
        );
      case MemoryCreateKind.person:
        final result = await showPersonCreateSheet(context);
        if (result == null) {
          return;
        }
        saved = await notifier.createPerson(
          displayName: result.displayName,
          relationship: result.relationship,
          summary: result.summary,
          importance: result.importance,
        );
        successMessage = l10n.memoryPagePersonCreated;
      case MemoryCreateKind.rule:
        final result = await showStructuredCreateSheet(
          context,
          title: l10n.memoryCreateRuleTitle,
          primaryLabel: l10n.commonTitle,
          detailLabel: l10n.memoryEditRuleTextLabel,
        );
        if (result == null) {
          return;
        }
        saved = await notifier.createRule(
          title: result.title,
          ruleText: result.detail,
          priority: result.importance,
        );
        successMessage = l10n.memoryPageRuleCreated;
    }

    if (!mounted) {
      return;
    }
    _showSnackBar(saved ? successMessage : _currentError());
  }

  Future<void> _editMemory(MemoryItem memory) async {
    final result = await showMemoryEditSheet(context, memory: memory);
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

    _showSnackBar(saved ? context.l10n.memoryPageMemoryUpdated : _currentError());
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

    _showSnackBar(archived ? context.l10n.memoryPageMemoryArchived : _currentError());
  }

  Future<void> _editPerson(PersonMemoryItem person) async {
    final l10n = context.l10n;
    final result = await showPersonEditSheet(context, person: person);
    if (result == null) {
      return;
    }

    if (result.delete) {
      final archived = await ref
          .read(memoryProvider.notifier)
          .archiveStructuredMemory(StructuredMemoryKind.person, person.id);
      if (mounted) {
        _showSnackBar(
          archived
              ? context.l10n.commonArchivedNamed(person.displayName)
              : _currentError(),
        );
      }
      return;
    }

    final existingAttributes = Map<String, dynamic>.from(person.attributes);
    if (result.birthday == null || result.birthday!.isEmpty) {
      existingAttributes.remove('birthday');
    } else {
      existingAttributes['birthday'] = result.birthday;
    }
    final metadata = Map<String, dynamic>.from(person.metadata);
    metadata['attributes'] = existingAttributes;

    final saved = await ref.read(memoryProvider.notifier).updatePerson(
          person.id,
          displayName: result.displayName,
          relationship: result.relationship,
          summary: result.summary,
          importance: person.importance,
          status: person.status,
          active: person.active,
          metadata: metadata,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPagePersonUpdated : _currentError());
    }
  }

  Future<void> _editEntity(EntityMemoryItem entity) async {
    final l10n = context.l10n;
    final result = await showStructuredEditSheet(
      context,
      title: l10n.memoryEditEditEntityTitle,
      typeLabel: entityTypeLabel(l10n, entity.entityType),
      primaryLabel: l10n.commonName,
      primaryValue: entity.displayName,
      detailLabel: l10n.commonSummary,
      detailValue: entity.summary,
      importanceLabel: l10n.commonImportance,
      importance: entity.importance,
      status: entity.status,
      active: entity.active,
      updatedAt: entity.updatedAt,
      createdAt: entity.createdAt,
      showImportance: false,
      showActive: false,
    );
    if (result == null) {
      return;
    }

    final saved = await ref.read(memoryProvider.notifier).updateEntity(
          entity.id,
          displayName: result.primary,
          summary: result.detail,
          importance: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPageEntityUpdated : _currentError());
    }
  }

  Future<void> _editRule(RuleMemoryItem rule) async {
    final l10n = context.l10n;
    final result = await showStructuredEditSheet(
      context,
      title: l10n.memoryEditEditRuleTitle,
      typeLabel: localizedMemoryRecordLabel(l10n, rule.ruleType),
      primaryLabel: l10n.commonTitle,
      primaryValue: rule.title,
      detailLabel: l10n.memoryEditRuleTextLabel,
      detailValue: rule.ruleText,
      extraLabel: l10n.memoryEditTriggerKeywordsLabel,
      extraValue: rule.triggerKeywords.join(', '),
      importanceLabel: l10n.commonPriority,
      importance: rule.priority,
      status: rule.status,
      active: rule.active,
      updatedAt: rule.updatedAt,
      createdAt: rule.createdAt,
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
      _showSnackBar(saved ? l10n.memoryPageRuleUpdated : _currentError());
    }
  }

  Future<void> _editPlan(PlanMemoryItem plan) async {
    final l10n = context.l10n;
    final result = await showStructuredEditSheet(
      context,
      title: l10n.memoryEditEditPlanTitle,
      typeLabel: localizedMemoryRecordLabel(l10n, plan.planType),
      primaryLabel: l10n.commonTitle,
      primaryValue: plan.title,
      detailLabel: l10n.commonDescription,
      detailValue: plan.description,
      extraLabel: l10n.memoryEditDesiredOutcomeLabel,
      extraValue: plan.desiredOutcome,
      importanceLabel: l10n.commonPriority,
      importance: plan.priority,
      status: plan.status,
      active: plan.active,
      updatedAt: plan.updatedAt,
      createdAt: plan.createdAt,
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
      _showSnackBar(saved ? l10n.memoryPagePlanUpdated : _currentError());
    }
  }

  Future<void> _addPlanMilestone(PlanMemoryItem plan) async {
    final l10n = context.l10n;
    final result = await showStructuredCreateSheet(
      context,
      title: l10n.memoryCreateMilestoneTitle,
      primaryLabel: l10n.commonTitle,
      detailLabel: l10n.commonDescription,
    );
    if (result == null) {
      return;
    }

    final saved = await ref.read(memoryProvider.notifier).createPlanMilestone(
          plan.id,
          title: result.title,
          description: result.detail,
          priority: result.importance,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPageMilestoneCreated : _currentError());
    }
  }

  Future<void> _editPlanMilestone(
    PlanMemoryItem plan,
    PlanMilestoneMemoryItem milestone,
  ) async {
    final l10n = context.l10n;
    final result = await showStructuredEditSheet(
      context,
      title: l10n.memoryEditEditMilestoneTitle,
      typeLabel: localizedMemoryRecordLabel(l10n, milestone.milestoneType),
      primaryLabel: l10n.commonTitle,
      primaryValue: milestone.title,
      detailLabel: l10n.commonDescription,
      detailValue: milestone.description,
      importanceLabel: l10n.commonPriority,
      importance: milestone.priority,
      status: milestone.status,
      active: milestone.active,
      updatedAt: milestone.updatedAt,
      createdAt: milestone.createdAt,
    );
    if (result == null) {
      return;
    }

    final saved = await ref.read(memoryProvider.notifier).updatePlanMilestone(
          milestone.id,
          title: result.primary,
          description: result.detail,
          priority: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPageMilestoneUpdated : _currentError());
    }
  }

  Future<void> _archiveStructuredMemory(
    StructuredMemoryKind kind,
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
        .archiveStructuredMemory(kind, id);
    if (mounted) {
      _showSnackBar(
        archived ? context.l10n.commonArchivedNamed(label) : _currentError(),
      );
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _currentError() {
    return ref.read(memoryProvider).errorMessage ?? context.l10n.memoryPageActionFailed;
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
              title: Text(context.l10n.memoryPageTitle),
              actions: [
                IconButton(
                  onPressed: state.isLoading || state.isSaving ? null : _startCreate,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: context.l10n.memoryCreateAddTooltip,
                ),
                IconButton(
                  onPressed: state.isLoading ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: context.l10n.memoryPageRefreshTooltip,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                    const SizedBox(height: 8),
                    SavedMemoryHeader(
                      onCreate: widget.showAppBar
                          ? null
                          : (state.isLoading || state.isSaving
                              ? null
                              : _startCreate),
                      createEnabled: !state.isLoading && !state.isSaving,
                    ),
                    const SizedBox(height: 4),
                    ActiveMemoryToggle(
                      value: state.activeOnly,
                      onChanged: state.isLoading ? null : _setActiveOnly,
                    ),
                    if (state.overviewCanLoadMore)
                      MemoryTruncationBanner(
                        canLoadMore: state.overviewCanLoadMore,
                        onLoadMore: state.isLoading
                            ? null
                            : () => ref
                                  .read(memoryProvider.notifier)
                                  .loadMoreSavedOverview(),
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
                child: MemoryEmptyState(
                  activeOnly: state.activeOnly,
                  onCreate: state.isLoading || state.isSaving
                      ? null
                      : _startCreate,
                ),
              )
            else if (filteredSaved.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MemoryFilteredEmptyState(),
              )
            else
              SavedMemoryGroupList(
                saved: filteredSaved,
                eventPreviewsFor: state.eventPreviewsFor,
                milestonePreviewsFor: state.milestonePreviewsFor,
                onEditMemory: _editMemory,
                onArchiveMemory: _archiveMemory,
                onEditPerson: _editPerson,
                onEditEntity: _editEntity,
                onEditRule: _editRule,
                onEditPlan: _editPlan,
                onAddPlanMilestone: _addPlanMilestone,
                onEditPlanMilestone: _editPlanMilestone,
                onArchiveStructuredMemory: _archiveStructuredMemory,
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: clarityScrollBottomClearance(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
