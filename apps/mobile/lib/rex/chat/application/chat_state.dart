import 'package:clarity/rex/chat/domain/chat_message.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.conversationId,
    this.errorMessage,
    this.textConfirmationPendingProposalId,
    this.focusMessageId,
    this.focusHighlightTerms = const [],
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? conversationId;
  final String? errorMessage;

  /// Text / Off+explicit say-yes pending id when no confirm card is shown.
  final String? textConfirmationPendingProposalId;

  /// When opening a search hit, scroll to this message instead of the bottom.
  final String? focusMessageId;

  /// Terms to highlight inside the focused search-hit message.
  final List<String> focusHighlightTerms;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? conversationId,
    bool clearConversationId = false,
    String? errorMessage,
    bool clearError = false,
    String? textConfirmationPendingProposalId,
    bool clearTextConfirmationPending = false,
    String? focusMessageId,
    bool clearFocusMessageId = false,
    List<String>? focusHighlightTerms,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      conversationId: clearConversationId
          ? null
          : conversationId ?? this.conversationId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      textConfirmationPendingProposalId: clearTextConfirmationPending
          ? null
          : textConfirmationPendingProposalId ??
              this.textConfirmationPendingProposalId,
      focusMessageId: clearFocusMessageId
          ? null
          : focusMessageId ?? this.focusMessageId,
      focusHighlightTerms: clearFocusMessageId
          ? const []
          : focusHighlightTerms ?? this.focusHighlightTerms,
    );
  }
}
