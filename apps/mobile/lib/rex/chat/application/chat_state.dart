import 'package:clarity/rex/chat/domain/chat_message.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.conversationId,
    this.errorMessage,
    this.textConfirmationPendingProposalId,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? conversationId;
  final String? errorMessage;

  /// Text / Off+explicit say-yes pending id when no confirm card is shown.
  final String? textConfirmationPendingProposalId;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? conversationId,
    bool clearConversationId = false,
    String? errorMessage,
    bool clearError = false,
    String? textConfirmationPendingProposalId,
    bool clearTextConfirmationPending = false,
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
    );
  }
}
