import 'package:clarity/features/assistant/chat/domain/chat_message.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.conversationId,
    this.errorMessage,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? conversationId;
  final String? errorMessage;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? conversationId,
    bool clearConversationId = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      conversationId: clearConversationId
          ? null
          : conversationId ?? this.conversationId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
