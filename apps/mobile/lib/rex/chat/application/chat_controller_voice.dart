// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'chat_controller.dart';

extension ChatControllerVoice on ChatController {
  void upsertVoiceUserMessage({
    required String localId,
    required String content,
  }) {
    final text = content.trim();
    if (text.isEmpty) {
      return;
    }

    final existingIndex = state.messages.indexWhere((message) => message.id == localId);
    if (existingIndex >= 0) {
      final updated = state.messages[existingIndex].copyWith(
        content: text,
        isVoiceInterim: true,
      );
      final messages = List<ChatMessage>.from(state.messages);
      messages[existingIndex] = updated;
      state = state.copyWith(
        messages: List.unmodifiable(messages),
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      messages: List.unmodifiable([
        ...state.messages,
        ChatMessage(
          id: localId,
          role: ChatMessageRole.user,
          content: text,
          timestamp: DateTime.now(),
          isVoiceInterim: true,
        ),
      ]),
      clearError: true,
    );
  }

  void finalizeVoiceUserMessage({
    required String localId,
    required String content,
  }) {
    final text = content.trim();
    if (text.isEmpty) {
      removeVoiceUserMessage(localId);
      return;
    }

    final existingIndex = state.messages.indexWhere((message) => message.id == localId);
    if (existingIndex >= 0) {
      final updated = state.messages[existingIndex].copyWith(
        content: text,
        isVoiceInterim: false,
      );
      final messages = List<ChatMessage>.from(state.messages);
      messages[existingIndex] = updated;
      state = state.copyWith(
        messages: List.unmodifiable(messages),
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      messages: List.unmodifiable([
        ...state.messages,
        ChatMessage(
          id: localId,
          role: ChatMessageRole.user,
          content: text,
          timestamp: DateTime.now(),
          isVoiceInterim: false,
        ),
      ]),
      clearError: true,
    );
  }

  void removeVoiceUserMessage(String localId) {
    if (localId.isEmpty) {
      return;
    }

    final filtered = state.messages
        .where((message) => message.id != localId)
        .toList(growable: false);
    if (filtered.length == state.messages.length) {
      return;
    }

    state = state.copyWith(
      messages: List.unmodifiable(filtered),
      clearError: true,
    );
  }
}
