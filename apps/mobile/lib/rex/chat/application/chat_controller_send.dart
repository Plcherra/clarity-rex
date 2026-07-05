// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'chat_controller.dart';

extension ChatControllerSend on ChatController {
  Future<bool> sendMessage(
    String content, {
    XFile? attachment,
    bool stream = true,
  }) async {
    final response = await _runSendMessageForAssistantResponse(
      content,
      attachment: attachment,
      stream: stream,
    );
    return response != null;
  }

  Future<String?> _runSendMessageForAssistantResponse(
    String content, {
    XFile? attachment,
    bool stream = true,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    final message = content.trim();
    if ((message.isEmpty && attachment == null) || state.isLoading) {
      return null;
    }

    writeConfirmation ??= _writeConfirmationForTypedAffirmation(message);

    if (attachment != null) {
      final attachmentError = await validateChatAttachmentFile(
        attachment,
        l10n: lookupForLocale(ref.read(localeControllerProvider).locale),
      );
      if (attachmentError != null) {
        state = state.copyWith(errorMessage: attachmentError, isLoading: false);
        return null;
      }
    }

    final attachmentMeta = await _attachmentMetadata(attachment);
    final userMessage = ChatMessage(
      id: 'local-user-${DateTime.now().microsecondsSinceEpoch}',
      role: ChatMessageRole.user,
      content: message,
      timestamp: DateTime.now(),
      attachmentLocalPath: attachmentMeta.localPath,
      attachmentPreviewBytes: attachmentMeta.previewBytes,
      attachmentName: attachmentMeta.name,
    );
    state = state.copyWith(
      messages: List.unmodifiable([...state.messages, userMessage]),
      isLoading: true,
      clearError: true,
    );

    if (stream && attachment == null) {
      return _sendStreamingMessage(
        message,
        attachment: attachment,
        writeConfirmation: writeConfirmation,
      );
    }

    return _sendNonStreamingMessageForResponse(
      message,
      attachment: attachment,
      writeConfirmation: writeConfirmation,
    );
  }

  Future<String?> _sendNonStreamingMessageForResponse(
    String message, {
    XFile? attachment,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    try {
      final api = ref.read(chatApiProvider);
      final financialContext = await _financialContext(message);
      final dashboardLink = _dashboardLinkAnchor(message, financialContext);
      final result = await api.sendMessage(
        message,
        conversationId: state.conversationId,
        attachment: attachment,
        financialContext: financialContext,
        writeConfirmation: writeConfirmation,
      );

      state = state.copyWith(
        conversationId: result.conversationId,
        messages: result.messages.isNotEmpty
            ? _messagesFromApiResponse(
                result,
                dashboardLink: dashboardLink,
              )
            : List.unmodifiable([
                ...state.messages,
                ChatMessage(
                  id: 'local-assistant-${DateTime.now().microsecondsSinceEpoch}',
                  role: ChatMessageRole.assistant,
                  content: result.response,
                  timestamp: DateTime.now(),
                  clarityActions: clarityActionCardsFromMemoryChanges(
                    result.memoryChanges,
                  ),
                  dashboardLinkAnchor: dashboardLink,
                ),
              ]),
        isLoading: false,
        clearError: true,
      );
      await _refreshSavedMemoryOverviewIfNeeded(result.memoryChanges);
      await _refreshGoalsOverviewIfNeeded(result.memoryChanges);
      return assistantTextFromApiResponse(result) ??
          latestAssistantContent(state.messages);
    } on ChatApiException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: localizedError(error));
      return null;
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: localizedError(error));
      return null;
    }
  }

  Future<String?> _sendStreamingMessage(
    String message, {
    XFile? attachment,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    final generation = ++_streamGeneration;
    final streamedAssistantId =
        'local-assistant-${DateTime.now().microsecondsSinceEpoch}';

    try {
      final api = ref.read(chatApiProvider);
      final financialContext = await _financialContext(message);
      final dashboardLink = _dashboardLinkAnchor(message, financialContext);
      await for (final event in api.streamMessage(
        message,
        conversationId: state.conversationId,
        attachment: attachment,
        financialContext: financialContext,
        writeConfirmation: writeConfirmation,
      )) {
        if (generation != _streamGeneration) {
          return null;
        }

        if (event is ChatStreamConversation) {
          state = state.copyWith(conversationId: event.conversationId);
        } else if (event is ChatStreamToken) {
          if (event.token.isEmpty) {
            continue;
          }
          state = state.copyWith(
            messages: _messagesWithStreamedToken(
              state.messages,
              streamedAssistantId,
              event.token,
            ),
          );
        } else if (event is ChatStreamDone) {
          final response = event.response;
          state = state.copyWith(
            conversationId: response.conversationId,
            messages: response.messages.isNotEmpty
                ? _messagesFromApiResponse(
                    response,
                    dashboardLink: dashboardLink,
                  )
                : _messagesWithAssistantExtras(
                    _messagesWithStreamingStopped(state.messages),
                    memoryChanges: response.memoryChanges,
                    dashboardLink: dashboardLink,
                  ),
            isLoading: false,
            clearError: true,
          );
          await _refreshSavedMemoryOverviewIfNeeded(response.memoryChanges);
          await _refreshGoalsOverviewIfNeeded(response.memoryChanges);
          return assistantTextFromApiResponse(response) ??
              latestAssistantContent(state.messages);
        }
      }

      state = state.copyWith(
        isLoading: false,
        messages: _messagesWithStreamingStopped(state.messages),
        clearError: true,
      );
      return latestAssistantContent(state.messages);
    } on ChatApiException catch (error) {
      if (generation == _streamGeneration) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: localizedError(error),
          messages: _messagesWithStreamingStopped(state.messages),
        );
      }
      return null;
    } on Object catch (error) {
      if (generation == _streamGeneration) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: localizedError(error),
          messages: _messagesWithStreamingStopped(state.messages),
        );
      }
      return null;
    }
  }

  List<ChatMessage> _messagesWithStreamedToken(
    List<ChatMessage> messages,
    String assistantId,
    String token,
  ) {
    if (messages.isNotEmpty &&
        messages.last.role == ChatMessageRole.assistant &&
        messages.last.isStreaming) {
      return List.unmodifiable([
        ...messages.take(messages.length - 1),
        messages.last.copyWith(content: '${messages.last.content}$token'),
      ]);
    }

    return List.unmodifiable([
      ...messages,
      ChatMessage(
        id: assistantId,
        role: ChatMessageRole.assistant,
        content: token,
        timestamp: DateTime.now(),
        isStreaming: true,
      ),
    ]);
  }

  List<ChatMessage> _messagesWithStreamingStopped(List<ChatMessage> messages) {
    return List.unmodifiable(
      messages
          .map(
            (message) => message.isStreaming
                ? message.copyWith(isStreaming: false)
                : message,
          )
          .toList(growable: false),
    );
  }

  Future<({String? localPath, List<int>? previewBytes, String? name})>
  _attachmentMetadata(XFile? attachment) async {
    if (attachment == null) {
      return (localPath: null, previewBytes: null, name: null);
    }

    final name = chatAttachmentName(attachment);
    if (!isChatImageAttachmentName(name)) {
      return (localPath: null, previewBytes: null, name: name);
    }

    try {
      final bytes = await attachment.readAsBytes();
      final path = attachment.path.trim();
      return (
        localPath: !kIsWeb && path.isNotEmpty ? path : null,
        previewBytes: bytes,
        name: name,
      );
    } on Object {
      return (localPath: null, previewBytes: null, name: name);
    }
  }
}
