import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/chat/application/conversation_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/chat/presentation/widgets/conversation_history_widgets.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';

class ConversationListPage extends ConsumerStatefulWidget {
  const ConversationListPage({
    super.key,
    this.showAppBar = true,
    this.onConversationSelected,
  });

  final bool showAppBar;
  final VoidCallback? onConversationSelected;

  @override
  ConsumerState<ConversationListPage> createState() =>
      _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage>
    with AutomaticKeepAliveClientMixin<ConversationListPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    Future.microtask(
      () => ref.read(conversationListProvider.notifier).loadConversations(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _deleteConversation(Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RexUiTokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Delete conversation?',
          style: TextStyle(color: RexUiTokens.text),
        ),
        content: const Text(
          'This removes the conversation and its messages from Clarity.',
          style: TextStyle(color: RexUiTokens.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: RexUiTokens.textMuted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: RexUiTokens.danger,
              foregroundColor: RexUiTokens.background,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final wasCurrent = ref.read(chatProvider).conversationId == conversation.id;
    final deleted = await ref
        .read(conversationListProvider.notifier)
        .deleteConversation(conversation.id);

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (!deleted) {
      final errorMessage =
          ref.read(conversationListProvider).errorMessage ??
          'Could not delete conversation.';
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Conversation deleted')),
    );

    if (wasCurrent) {
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: RexUiTokens.accent,
              onPrimary: RexUiTokens.background,
              surface: RexUiTokens.surfaceRaised,
              onSurface: RexUiTokens.text,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: RexUiTokens.surfaceRaised,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
    final currentConversation = ref.watch(currentConversationProvider);
    final filteredConversations = filterConversationsByDate(
      state.conversations,
      state.dateFilter,
    );
    final filteredSearchResults = filterConversationSearchResultsByDate(
      state.searchResults,
      state.dateFilter,
    );

    final body = RefreshIndicator(
      color: RexUiTokens.accent,
      backgroundColor: RexUiTokens.surfaceRaised,
      onRefresh: () =>
          ref.read(conversationListProvider.notifier).loadConversations(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!widget.showAppBar)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chats',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: RexUiTokens.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: state.isLoading ? null : _newConversation,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'New conversation',
                      color: RexUiTokens.accent,
                    ),
                  ],
                ),
              ),
            ),
          if (state.errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _HistoryErrorBanner(message: state.errorMessage!),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ConversationSearchField(
                    controller: _searchController,
                    isSearching: state.isSearching,
                    onSubmitted: _submitSearch,
                    onClear: _clearSearch,
                  ),
                  const SizedBox(height: RexUiTokens.space12),
                  _ConversationDateFilters(
                    filter: state.dateFilter,
                    onFilterChanged: _setDateFilter,
                    onCustomTap: _pickCustomDateFilter,
                  ),
                ],
              ),
            ),
          ),
          if (state.searchQuery.isNotEmpty)
            _ConversationSearchResultsSliver(
              state: state,
              results: filteredSearchResults,
              onResultTap: _openSearchResult,
            )
          else if (state.isLoading && state.conversations.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: RexUiTokens.accent),
              ),
            )
          else if (filteredConversations.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _EmptyConversationState(
                    title: state.dateFilter.isActive
                        ? 'No chats in ${state.dateFilter.label(DateTime.now()).toLowerCase()}'
                        : 'No chats yet',
                    message: state.dateFilter.isActive
                        ? 'Clear the date filter or choose a wider range.'
                        : 'Start a fresh conversation when you are ready.',
                    isLoading: state.isLoading,
                    onNewConversation: _newConversation,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate(
                conversationGroups(filteredConversations)
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
                            onDelete: () => _deleteConversation(conversation),
                          ),
                      ],
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );

    return RexScaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Chats'),
              actions: [
                IconButton(
                  onPressed: state.isLoading ? null : _newConversation,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'New conversation',
                  color: RexUiTokens.accent,
                ),
              ],
            )
          : null,
      body: body,
    );
  }
}

class _ConversationSearchField extends StatelessWidget {
  const _ConversationSearchField({
    required this.controller,
    required this.isSearching,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: RexUiTokens.text),
      decoration: InputDecoration(
        hintText: 'Search chats',
        hintStyle: const TextStyle(color: RexUiTokens.textSubtle),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: RexUiTokens.textSubtle,
        ),
        suffixIcon: isSearching
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: RexUiTokens.accent,
                  ),
                ),
              )
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                color: RexUiTokens.textSubtle,
              ),
        filled: true,
        fillColor: RexUiTokens.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RexUiTokens.radiusLarge),
          borderSide: const BorderSide(color: RexUiTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RexUiTokens.radiusLarge),
          borderSide: const BorderSide(color: RexUiTokens.accent),
        ),
      ),
    );
  }
}

class _ConversationSearchResultsSliver extends StatelessWidget {
  const _ConversationSearchResultsSliver({
    required this.state,
    required this.results,
    required this.onResultTap,
  });

  final ConversationListState state;
  final List<ConversationSearchResult> results;
  final ValueChanged<ConversationSearchResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    if (state.isSearching && state.searchResults.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: RexUiTokens.accent),
        ),
      );
    }

    if (results.isEmpty) {
      final suffix = state.dateFilter.isActive
          ? ' in ${state.dateFilter.label(DateTime.now()).toLowerCase()}'
          : '';
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No chats matched "${state.searchQuery}"$suffix',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: RexUiTokens.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final result = results[index];
        return ConversationSearchResultTile(
          result: result,
          onTap: () => onResultTap(result),
        );
      }, childCount: results.length),
    );
  }
}

class _ConversationDateFilters extends StatelessWidget {
  const _ConversationDateFilters({
    required this.filter,
    required this.onFilterChanged,
    required this.onCustomTap,
  });

  final ConversationDateFilter filter;
  final ValueChanged<ConversationDateFilter> onFilterChanged;
  final VoidCallback onCustomTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final chips = <Widget>[
      _ConversationFilterChip(
        label: 'All',
        selected: filter.type == ConversationDateFilterType.all,
        onTap: () => onFilterChanged(const ConversationDateFilter.all()),
      ),
      _ConversationFilterChip(
        label: 'Today',
        selected: filter.type == ConversationDateFilterType.today,
        onTap: () => onFilterChanged(const ConversationDateFilter.today()),
      ),
      _ConversationFilterChip(
        label: 'This week',
        selected: filter.type == ConversationDateFilterType.thisWeek,
        onTap: () => onFilterChanged(const ConversationDateFilter.thisWeek()),
      ),
      _ConversationFilterChip(
        label: 'This month',
        selected: filter.type == ConversationDateFilterType.thisMonth,
        onTap: () => onFilterChanged(const ConversationDateFilter.thisMonth()),
      ),
      _ConversationFilterChip(
        label: filter.type == ConversationDateFilterType.custom
            ? filter.label(now)
            : 'Custom',
        icon: Icons.calendar_month_rounded,
        selected: filter.type == ConversationDateFilterType.custom,
        onTap: onCustomTap,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }
}

class _ConversationFilterChip extends StatelessWidget {
  const _ConversationFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? RexUiTokens.background
        : RexUiTokens.textMuted;
    return Padding(
      padding: const EdgeInsets.only(right: RexUiTokens.space8),
      child: ActionChip(
        avatar: icon == null ? null : Icon(icon, size: 16, color: foreground),
        label: Text(label),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
        backgroundColor: selected
            ? RexUiTokens.accent
            : RexUiTokens.surfaceRaised,
        side: BorderSide(
          color: selected ? RexUiTokens.accent : RexUiTokens.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        ),
        onPressed: onTap,
      ),
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState({
    required this.title,
    required this.message,
    required this.isLoading,
    required this.onNewConversation,
  });

  final String title;
  final String message;
  final bool isLoading;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RexSurface(
      padding: const EdgeInsets.all(RexUiTokens.space24),
      color: RexUiTokens.surface,
      radius: RexUiTokens.radiusLarge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, color: RexUiTokens.accent, size: 34),
          const SizedBox(height: RexUiTokens.space16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: RexUiTokens.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: RexUiTokens.space8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: RexUiTokens.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: RexUiTokens.space20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: RexUiTokens.accent,
              foregroundColor: RexUiTokens.background,
            ),
            onPressed: isLoading ? null : onNewConversation,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New chat'),
          ),
        ],
      ),
    );
  }
}

class _HistoryErrorBanner extends StatelessWidget {
  const _HistoryErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return RexSurface(
      padding: const EdgeInsets.all(RexUiTokens.space16),
      color: RexUiTokens.danger.withValues(alpha: 0.12),
      borderColor: RexUiTokens.danger.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: RexUiTokens.danger,
            size: 20,
          ),
          const SizedBox(width: RexUiTokens.space12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RexUiTokens.text,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
