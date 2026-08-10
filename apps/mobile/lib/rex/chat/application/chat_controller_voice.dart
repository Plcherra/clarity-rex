// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'chat_controller.dart';

bool _isLocalVoiceMessageId(String id) => id.startsWith('local-voice-');

String _normalizeVoiceMessageContent(String content) =>
    content.trim().replaceAll(RegExp(r'\s+'), ' ');

bool _localVoiceIsCoveredByBackendUser({
  required String localContent,
  required Set<String> backendUserContents,
  required Iterable<String> backendUserMessages,
}) {
  final normalized = _normalizeVoiceMessageContent(localContent);
  if (normalized.isEmpty) {
    return true;
  }
  if (backendUserContents.contains(normalized)) {
    return true;
  }
  for (final backendMessage in backendUserMessages) {
    final normalizedBackend = _normalizeVoiceMessageContent(backendMessage);
    if (normalizedBackend.isEmpty) {
      continue;
    }
    if (normalizedBackend.contains(normalized)) {
      return true;
    }
  }
  return false;
}

List<ChatMessage> mergeBackendMessagesPreservingLocalVoice({
  required List<ChatMessage> local,
  required List<ChatMessage> backend,
}) {
  final backendUserMessages = backend
      .where((message) => message.role == ChatMessageRole.user)
      .map((message) => message.content)
      .toList(growable: false);
  final backendUserContents = {
    for (final content in backendUserMessages)
      _normalizeVoiceMessageContent(content),
  };

  final localVoiceToKeep = <ChatMessage>[];
  for (final message in local) {
    if (!_isLocalVoiceMessageId(message.id)) {
      continue;
    }
    if (message.role != ChatMessageRole.user) {
      continue;
    }

    if (_localVoiceIsCoveredByBackendUser(
      localContent: message.content,
      backendUserContents: backendUserContents,
      backendUserMessages: backendUserMessages,
    )) {
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

  void removeVoiceUserMessage(
    String localId, {
    bool evenIfFinalized = false,
  }) {
    if (localId.isEmpty) {
      return;
    }

    final existingIndex =
        state.messages.indexWhere((message) => message.id == localId);
    if (existingIndex < 0) {
      return;
    }
    // Soft-recover after a finalized-but-abandoned streaming turn must clear
    // the orphan bubble; interim-only removal left duplicates on screen.
    if (!evenIfFinalized && !state.messages[existingIndex].isVoiceInterim) {
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

  void removeStaleLocalVoiceUserMessages({
    required String keepLocalId,
    required String finalContent,
  }) {
    final filtered = state.messages.where((message) {
      if (!_isLocalVoiceMessageId(message.id)) {
        return true;
      }
      return message.id == keepLocalId;
    }).toList(growable: false);

    if (filtered.length == state.messages.length) {
      return;
    }

    state = state.copyWith(
      messages: List.unmodifiable(filtered),
      clearError: true,
    );
  }

  void removeAllLocalVoiceUserMessages() {
    final filtered = state.messages
        .where((message) => !_isLocalVoiceMessageId(message.id))
        .toList(growable: false);
    if (filtered.length == state.messages.length) {
      return;
    }
    state = state.copyWith(
      messages: List.unmodifiable(filtered),
      clearError: true,
    );
  }

  /// Drop only in-flight interim local-voice bubbles (keep finalized ones).
  void discardInterimLocalVoiceUserMessages({String? keepLocalId}) {
    final filtered = state.messages.where((message) {
      if (!_isLocalVoiceMessageId(message.id) || !message.isVoiceInterim) {
        return true;
      }
      if (keepLocalId != null && message.id == keepLocalId) {
        return true;
      }
      return false;
    }).toList(growable: false);
    if (filtered.length == state.messages.length) {
      return;
    }
    state = state.copyWith(
      messages: List.unmodifiable(filtered),
      clearError: true,
    );
  }

  /// Longest interim local-voice user text — recovery when the voice buffer
  /// was cleared but the bubble is still on screen.
  String? latestInterimVoiceUserContent() {
    String? best;
    for (final message in state.messages) {
      if (!_isLocalVoiceMessageId(message.id) ||
          message.role != ChatMessageRole.user ||
          !message.isVoiceInterim) {
        continue;
      }
      final text = message.content.trim();
      if (text.isEmpty) {
        continue;
      }
      if (best == null || text.length >= best.length) {
        best = text;
      }
    }
    return best;
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
