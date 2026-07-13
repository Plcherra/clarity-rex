import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/layout/web_centered_dialog.dart';
import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/chat/application/conversation_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/chat/presentation/pages/conversation_list_actions.dart';
import 'package:clarity/rex/chat/presentation/pages/conversation_list_chrome.dart';
import 'package:clarity/rex/chat/presentation/widgets/conversation_history_widgets.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/theme/clarity_sheet_insets.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

class ConversationListPage extends ConsumerStatefulWidget {
  const ConversationListPage({
    super.key,
    this.showAppBar = true,
    this.onConversationSelected,
    this.compactSidebar = false,
  });

  final bool showAppBar;
  final VoidCallback? onConversationSelected;
  final bool compactSidebar;

  @override
  ConsumerState<ConversationListPage> createState() =>
      _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage>
    with AutomaticKeepAliveClientMixin<ConversationListPage> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    Future.microtask(
      () => ref.read(conversationListProvider.notifier).loadConversations(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _openConversation(Conversation conversation) async {
    await ref.read(chatProvider.notifier).loadConversation(conversation.id);
    if (!mounted) {
      return;
    }

    if (widget.onConversationSelected != null) {
      widget.onConversationSelected!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _newConversation() async {
    final conversation = await ref
        .read(conversationListProvider.notifier)
        .createConversation();
    if (conversation == null) {
      return;
    }

    ref.read(chatProvider.notifier).startConversation(conversation.id);
    if (!mounted) {
      return;
    }

    if (widget.onConversationSelected != null) {
      widget.onConversationSelected!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openSearchResult(ConversationSearchResult result) async {
    await ref
        .read(chatProvider.notifier)
        .loadConversation(result.conversationId);
    if (!mounted) {
      return;
    }

    if (widget.onConversationSelected != null) {
      widget.onConversationSelected!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _submitSearch(String value) {
    ref.read(conversationListProvider.notifier).searchConversations(value);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(conversationListProvider.notifier).clearSearch();
  }

  void _setDateFilter(ConversationDateFilter filter) {
    ref.read(conversationListProvider.notifier).setDateFilter(filter);
  }

  Future<void> _pickCustomDateFilter() async {
    final now = DateTime.now();
    final currentFilter = ref.read(conversationListProvider).dateFilter;
    final initialRange = currentFilter.type == ConversationDateFilterType.custom
        ? DateTimeRange(
            start: currentFilter.start ?? now,
            end: currentFilter.end ?? now,
          )
        : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      builder: (context, child) =>
          wrapWebCenteredDialog(context, child, maxWidth: 420, maxHeight: 520),
    );
    if (!mounted || range == null) {
      return;
    }

    _setDateFilter(
      ConversationDateFilter.custom(start: range.start, end: range.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(conversationListProvider);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final now = DateTime.now();
    final currentConversation = ref.watch(currentConversationProvider);
    final filteredConversations = filterConversationsByDate(
      state.conversations,
      state.dateFilter,
    );
    final filteredSearchResults = filterConversationSearchResultsByDate(
      state.searchResults,
      state.dateFilter,
    );
    final insetH = conversationListHorizontalInset(
      context,
      compactSidebar: widget.compactSidebar,
    );
    final native = ClarityNativeLayout.active(context);
    final searchTop = native
        ? 8.0
        : (widget.compactSidebar ? 8.0 : 12.0);

    final body = Scrollbar(
      controller: _scrollController,
      thumbVisibility: widget.compactSidebar,
      child: RefreshIndicator(
        color: colors.accent,
        backgroundColor: colors.surfaceElevated,
        onRefresh: () =>
            ref.read(conversationListProvider.notifier).loadConversations(),
        child: CustomScrollView(
          controller: _scrollController,
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (!widget.showAppBar)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    insetH,
                    8,
                    widget.compactSidebar && !native ? 8 : insetH,
                    8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.conversationListTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: state.isLoading ? null : _newConversation,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(l10n.conversationListNewChat),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(insetH, 12, insetH, 0),
                  child: ConversationListErrorBanner(
                    message: state.errorMessage!,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(insetH, searchTop, insetH, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConversationListSearchField(
                      controller: _searchController,
                      isSearching: state.isSearching,
                      onSubmitted: _submitSearch,
                      onClear: _clearSearch,
                    ),
                    const SizedBox(height: RexUiTokens.space12),
                    ConversationListDateFilters(
                      filter: state.dateFilter,
                      onFilterChanged: _setDateFilter,
                      onCustomTap: _pickCustomDateFilter,
                    ),
                  ],
                ),
              ),
            ),
            if (state.searchQuery.isNotEmpty)
              ConversationListSearchResultsSliver(
                state: state,
                results: filteredSearchResults,
                onResultTap: _openSearchResult,
              )
            else if (state.isLoading && state.conversations.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: ClarityPathLoader(
                    size: 52,
                    label: l10n.conversationListLoading,
                  ),
                ),
              )
            else if (filteredConversations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConversationListEmptyState(
                      title: state.dateFilter.isActive
                          ? l10n.conversationListEmptyFilteredTitle(
                              conversationDateFilterLabel(
                                l10n,
                                state.dateFilter,
                                now,
                              ).toLowerCase(),
                            )
                          : l10n.conversationListEmptyTitle,
                      message: state.dateFilter.isActive
                          ? l10n.conversationListEmptyFilteredMessage
                          : l10n.conversationListEmptyMessage,
                      isLoading: state.isLoading,
                      onNewConversation: _newConversation,
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildListDelegate(
                  conversationGroups(l10n, filteredConversations)
                      .expand<Widget>(
                        (group) => [
                          ConversationDateHeader(
                            label: group.label,
                            count: group.conversations.length,
                          ),
                          for (final conversation in group.conversations)
                            ConversationHistoryTile(
                              conversation: conversation,
                              isSelected:
                                  conversation.id == currentConversation?.id,
                              onTap: () => _openConversation(conversation),
                              onDelete: () => deleteConversationFlow(
                                context: context,
                                ref: ref,
                                conversation: conversation,
                                compactSidebar: widget.compactSidebar,
                                onConversationSelected:
                                    widget.onConversationSelected,
                              ),
                              onRename: () => renameConversationFlow(
                                context: context,
                                ref: ref,
                                conversation: conversation,
                              ),
                              compact: widget.compactSidebar,
                            ),
                        ],
                      )
                      .toList(growable: false),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: clarityScrollBottomClearance(context)),
            ),
          ],
        ),
      ),
    );

    return RexScaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.conversationListTitle),
              actions: [
                IconButton(
                  onPressed: state.isLoading ? null : _newConversation,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: l10n.conversationListNewConversationTooltip,
                  color: context.clarityColors.accent,
                ),
              ],
            )
          : null,
      body: body,
    );
  }
}
