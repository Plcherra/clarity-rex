import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';

String? assistantTextFromApiResponse(ChatApiResponse response) {
  if (response.messages.isEmpty) {
    final responseText = response.response.trim();
    return responseText.isEmpty ? null : responseText;
  }

  for (final message in response.messages.reversed) {
    if (message.role == 'assistant' && message.content.trim().isNotEmpty) {
      return message.content;
    }
  }
  return null;
}

String? latestAssistantContent(List<ChatMessage> messages) {
  for (final message in messages.reversed) {
    if (message.role == ChatMessageRole.assistant &&
        message.content.trim().isNotEmpty) {
      return message.content;
    }
  }
  return null;
}
