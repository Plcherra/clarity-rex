// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'chat_controller.dart';

bool _isLocalVoiceMessageId(String id) => id.startsWith('local-voice-');

String _normalizeVoiceMessageContent(String content) =>
    content.trim().replaceAll(RegExp(r'\s+'), ' ');

List<ChatMessage> mergeBackendMessagesPreservingLocalVoice({
  required List<ChatMessage> local,
  required List<ChatMessage> backend,
}) {
  final backendUserContents = {
    for (final message in backend)
      if (message.role == ChatMessageRole.user)
        _normalizeVoiceMessageContent(message.content),
  };

  final localVoiceToKeep = <ChatMessage>[];
  for (final message in local) {
    if (!_isLocalVoiceMessageId(message.id)) {
      continue;
    }
    if (message.role != ChatMessageRole.user) {
      continue;
    }

    final normalized = _normalizeVoiceMessageContent(message.content);
    if (!message.isVoiceInterim && backendUserContents.contains(normalized)) {
      continue;
    }
    localVoiceToKeep.add(message);
  }

  if (localVoiceToKeep.isEmpty) {
    return List.unmodifiable(backend);
  }

  final merged = List<ChatMessage>.from(backend);
  var insertAt = merged.length;
  while (insertAt > 0 && merged[insertAt - 1].role == ChatMessageRole.assistant) {
    insertAt--;
  }
  merged.insertAll(insertAt, localVoiceToKeep);
  return List.unmodifiable(merged);
}

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
      final existingIndex =
          state.messages.indexWhere((message) => message.id == localId);
      if (existingIndex >= 0 &&
          state.messages[existingIndex].isVoiceInterim) {
        removeVoiceUserMessage(localId);
      }
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

    final existingIndex =
        state.messages.indexWhere((message) => message.id == localId);
    if (existingIndex < 0) {
      return;
    }
    if (!state.messages[existingIndex].isVoiceInterim) {
      return;
    }

    final filtered = state.messages
        .where((message) => message.id != localId)
        .toList(growable: false);
    state = state.copyWith(
      messages: List.unmodifiable(filtered),
      clearError: true,
    );
  }

  bool hasUserMessageWithContent(String content) {
    final normalized = _normalizeVoiceMessageContent(content);
    if (normalized.isEmpty) {
      return false;
    }
    return state.messages.any(
      (message) =>
          message.role == ChatMessageRole.user &&
          _normalizeVoiceMessageContent(message.content) == normalized,
    );
  }
}
