import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_l10n.dart';
import 'package:clarity/core/layout/clarity_native_layout.dart';
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

part 'memory_page_actions.dart';

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

  Future<void> _setQuickFilter(MemoryQuickFilter filter) async {
    if (_quickFilter == filter) {
      return;
    }
    setState(() => _quickFilter = filter);
  }

  Future<void> _refresh() =>
      ref.read(memoryProvider.notifier).loadSavedOverview();

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
                  onPressed: state.isLoading || state.isSaving
                      ? null
                      : _startCreate,
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
        child: Scrollbar(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: ClarityNativeLayout.active(context)
                      ? ClarityNativeLayout.pagePadding(
                          context,
                          top: 8,
                          bottom: 8,
                        )
                      : const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                          child: MemoryErrorBanner(
                            message: state.errorMessage!,
                          ),
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
                child: SizedBox(height: clarityScrollBottomClearance(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
