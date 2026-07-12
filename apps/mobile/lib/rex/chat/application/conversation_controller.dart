import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/core/l10n/friendly_service_error.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/rex/chat/application/chat_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/chat/presentation/widgets/conversation_history_widgets.dart';

final conversationListProvider =
    NotifierProvider<ConversationListController, ConversationListState>(
      ConversationListController.new,
    );

final currentConversationProvider = Provider<Conversation?>((ref) {
  final conversationId = ref.watch(
    chatProvider.select((state) => state.conversationId),
  );
  if (conversationId == null) {
    return null;
  }

  final conversations = ref.watch(
    conversationListProvider.select((state) => state.conversations),
  );
  for (final conversation in conversations) {
    if (conversation.id == conversationId) {
      return conversation;
    }
  }

  return null;
});

class ConversationListState {
  const ConversationListState({
    this.conversations = const [],
    this.searchResults = const [],
    this.searchQuery = '',
    this.dateFilter = const ConversationDateFilter.all(),
    this.isLoading = false,
    this.isSearching = false,
    this.errorMessage,
  });

  final List<Conversation> conversations;
  final List<ConversationSearchResult> searchResults;
  final String searchQuery;
  final ConversationDateFilter dateFilter;
  final bool isLoading;
  final bool isSearching;
  final String? errorMessage;

  ConversationListState copyWith({
    List<Conversation>? conversations,
    List<ConversationSearchResult>? searchResults,
    String? searchQuery,
    ConversationDateFilter? dateFilter,
    bool? isLoading,
    bool? isSearching,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      dateFilter: dateFilter ?? this.dateFilter,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

enum ConversationDateFilterType { all, today, thisWeek, thisMonth, custom }

class ConversationDateFilter {
  const ConversationDateFilter._({required this.type, this.start, this.end});

  const ConversationDateFilter.all()
    : this._(type: ConversationDateFilterType.all);

  const ConversationDateFilter.today()
    : this._(type: ConversationDateFilterType.today);

  const ConversationDateFilter.thisWeek()
    : this._(type: ConversationDateFilterType.thisWeek);

  const ConversationDateFilter.thisMonth()
    : this._(type: ConversationDateFilterType.thisMonth);

  const ConversationDateFilter.custom({
    required DateTime start,
    required DateTime end,
  }) : this._(type: ConversationDateFilterType.custom, start: start, end: end);

  final ConversationDateFilterType type;
  final DateTime? start;
  final DateTime? end;

  bool get isActive => type != ConversationDateFilterType.all;

  String label(DateTime now) {
    return switch (type) {
      ConversationDateFilterType.all => 'All',
      ConversationDateFilterType.today => 'Today',
      ConversationDateFilterType.thisWeek => 'This week',
      ConversationDateFilterType.thisMonth => 'This month',
      ConversationDateFilterType.custom => _customLabel(now),
    };
  }

  String _customLabel(DateTime now) {
    final startDate = start;
    final endDate = end;
    if (startDate == null || endDate == null) {
      return 'Custom';
    }
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);
    if (normalizedStart == normalizedEnd) {
      return '${normalizedStart.month}/${normalizedStart.day}/${normalizedStart.year}';
    }
    return '${normalizedStart.month}/${normalizedStart.day} - ${normalizedEnd.month}/${normalizedEnd.day}';
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationDateFilter &&
        other.type == type &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(type, start, end);
}

class ConversationListController extends Notifier<ConversationListState> {
  @override
  ConversationListState build() => const ConversationListState();

  String _localizedError(Object error) {
    return friendlyServiceError(
      lookupForLocale(ref.read(localeControllerProvider).locale),
      error,
    );
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final conversations = await ref
          .read(conversationApiProvider)
          .getConversations();
      state = state.copyWith(
        conversations: conversations,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: _localizedError(error));
    }
  }

  Future<Conversation?> createConversation() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final conversation = await ref
          .read(conversationApiProvider)
          .createConversation();
      state = state.copyWith(
        conversations: List.unmodifiable([
          conversation,
          ...state.conversations,
        ]),
        isLoading: false,
        clearError: true,
      );
      return conversation;
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: _localizedError(error));
      return null;
    }
  }

  Future<bool> deleteConversation(String conversationId) async {
    final previousConversations = state.conversations;
    final updatedConversations = previousConversations
        .where((conversation) => conversation.id != conversationId)
        .toList(growable: false);

    state = state.copyWith(
      conversations: updatedConversations,
      clearError: true,
    );

    try {
      await ref
          .read(conversationApiProvider)
          .deleteConversation(conversationId);

      if (ref.read(chatProvider).conversationId == conversationId) {
        ref.read(chatProvider.notifier).reset();
      }

      return true;
    } on Object catch (error) {
      state = state.copyWith(
        conversations: previousConversations,
        errorMessage: _localizedError(error),
      );
      return false;
    }
  }

  Future<bool> renameConversation({
    required String conversationId,
    required String title,
  }) async {
    final trimmed = clampConversationTitle(title);
    if (trimmed.isEmpty) {
      return false;
    }

    final previousConversations = state.conversations;
    final optimistic = previousConversations
        .map(
          (conversation) => conversation.id == conversationId
              ? conversation.copyWith(title: trimmed)
              : conversation,
        )
        .toList(growable: false);

    state = state.copyWith(conversations: optimistic, clearError: true);

    try {
      final updated = await ref
          .read(conversationApiProvider)
          .updateConversationTitle(
            conversationId: conversationId,
            title: trimmed,
          );
      state = state.copyWith(
        conversations: previousConversations
            .map(
              (conversation) =>
                  conversation.id == conversationId ? updated : conversation,
            )
            .toList(growable: false),
        clearError: true,
      );
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        conversations: previousConversations,
        errorMessage: _localizedError(error),
      );
      return false;
    }
  }

  Future<void> searchConversations(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        searchQuery: '',
        searchResults: const [],
        isSearching: false,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      searchQuery: trimmed,
      isSearching: true,
      clearError: true,
    );

    try {
      final results = await ref
          .read(conversationApiProvider)
          .searchConversations(trimmed);
      if (state.searchQuery != trimmed) {
        return;
      }
      state = state.copyWith(
        searchResults: results,
        isSearching: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: _localizedError(error),
      );
    }
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      searchResults: const [],
      isSearching: false,
      clearError: true,
    );
  }

  void setDateFilter(ConversationDateFilter filter) {
    state = state.copyWith(dateFilter: filter, clearError: true);
  }

  void clearDateFilter() {
    state = state.copyWith(
      dateFilter: const ConversationDateFilter.all(),
      clearError: true,
    );
  }
}
