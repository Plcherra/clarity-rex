import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/actions/data/clarity_actions_api.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/application/chat_action_result_formatter.dart';
import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/data/chat_api.dart';
import 'package:clarity/rex/chat/application/chat_memory_change_parser.dart';
import 'package:clarity/rex/chat/application/chat_response_text.dart';
import 'package:clarity/rex/chat/application/chat_state.dart';
import 'package:clarity/rex/data/financial_context_service.dart';
import 'package:clarity/rex/memory/application/memory_controller.dart';

export 'package:clarity/rex/chat/application/chat_state.dart';

final chatApiProvider = Provider<ChatApi>((ref) => ChatApi());

final chatProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends Notifier<ChatState> {
  int _streamGeneration = 0;

  @override
  ChatState build() => const ChatState();

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: List.unmodifiable([...state.messages, message]),
      clearError: true,
    );
  }

  void setConversationId(String? conversationId) {
    state = state.copyWith(
      conversationId: conversationId,
      clearConversationId: conversationId == null,
    );
  }

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message, isLoading: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> executeClarityAction(ClarityActionCard action) async {
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(status: 'applying', clearError: true),
    );

    try {
      final result = await ref
          .read(clarityActionsApiProvider)
          .execute(
            action: action.action,
            payload: action.payload,
            confirmed: true,
          );
      _updateClarityAction(
        action.id,
        (current) => current.copyWith(
          status: result.status == 'applied' ? 'applied' : result.status,
          result: result.result,
          clearError: true,
        ),
      );
      ref.read(assistantFinancialContextServiceProvider)?.notifyDataChanged();
      addMessage(
        ChatMessage(
          id: 'local-assistant-action-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatMessageRole.assistant,
          content: actionResultMessage(action.action, result.result),
          timestamp: DateTime.now(),
        ),
      );
    } on ClarityActionsApiException catch (error) {
      _updateClarityAction(
        action.id,
        (current) =>
            current.copyWith(status: 'failed', errorMessage: error.message),
      );
    } on Object catch (error) {
      _updateClarityAction(
        action.id,
        (current) =>
            current.copyWith(status: 'failed', errorMessage: error.toString()),
      );
    }
  }

  void dismissClarityAction(ClarityActionCard action) {
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(status: 'dismissed', clearError: true),
    );
  }

  void reset() {
    _streamGeneration++;
    state = const ChatState();
  }

  void startConversation(String conversationId) {
    state = ChatState(conversationId: conversationId);
  }

  void applyBackendMessages({
    required String conversationId,
    required List<ChatApiMessage> messages,
    String? fallbackAssistantResponse,
    Map<String, dynamic>? memoryChanges,
  }) {
    final nextMessages = messages.isNotEmpty
        ? _messagesFromApiMessages(messages, memoryChanges: memoryChanges)
        : state.messages;

    state = state.copyWith(
      conversationId: conversationId,
      messages: nextMessages,
      isLoading: false,
      clearError: true,
    );

    if (messages.isEmpty &&
        fallbackAssistantResponse != null &&
        fallbackAssistantResponse.trim().isNotEmpty) {
      addMessage(
        ChatMessage(
          id: 'local-assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatMessageRole.assistant,
          content: fallbackAssistantResponse.trim(),
          timestamp: DateTime.now(),
          clarityActions: clarityActionCardsFromMemoryChanges(memoryChanges),
        ),
      );
    }
    unawaited(_refreshSavedMemoryOverviewIfNeeded(memoryChanges));
  }

  Future<void> loadConversation(String conversationId) async {
    state = state.copyWith(
      conversationId: conversationId,
      isLoading: true,
      clearError: true,
    );

    try {
      final messages = await ref
          .read(conversationApiProvider)
          .getConversationMessages(conversationId);
      state = state.copyWith(
        messages: messages,
        conversationId: conversationId,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void cancelStreaming() {
    _streamGeneration++;
    state = state.copyWith(
      isLoading: false,
      messages: _messagesWithStreamingStopped(state.messages),
    );
  }

  Future<bool> sendMessage(
    String content, {
    XFile? attachment,
    bool stream = true,
  }) async {
    final response = await sendMessageForAssistantResponse(
      content,
      attachment: attachment,
      stream: stream,
    );
    return response != null;
  }

  Future<String?> sendMessageForAssistantResponse(
    String content, {
    XFile? attachment,
    bool stream = true,
  }) async {
    final message = content.trim();
    if (message.isEmpty || state.isLoading) {
      return null;
    }

    if (attachment != null) {
      final attachmentError = await validateChatAttachmentFile(attachment);
      if (attachmentError != null) {
        state = state.copyWith(errorMessage: attachmentError, isLoading: false);
        return null;
      }
    }

    final userMessage = ChatMessage(
      id: 'local-user-${DateTime.now().microsecondsSinceEpoch}',
      role: ChatMessageRole.user,
      content: message,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: List.unmodifiable([...state.messages, userMessage]),
      isLoading: true,
      clearError: true,
    );

    if (stream) {
      return _sendStreamingMessage(message, attachment: attachment);
    }

    return _sendNonStreamingMessageForResponse(message, attachment: attachment);
  }

  Future<String?> _sendNonStreamingMessageForResponse(
    String message, {
    XFile? attachment,
  }) async {
    try {
      final api = ref.read(chatApiProvider);
      final financialContext = await _financialContext(message);
      final result = await api.sendMessage(
        message,
        conversationId: state.conversationId,
        attachment: attachment,
        financialContext: financialContext,
      );

      state = state.copyWith(
        conversationId: result.conversationId,
        messages: result.messages.isNotEmpty
            ? _messagesFromApiResponse(result)
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
                ),
              ]),
        isLoading: false,
        clearError: true,
      );
      await _refreshSavedMemoryOverviewIfNeeded(result.memoryChanges);
      return assistantTextFromApiResponse(result) ??
          latestAssistantContent(state.messages);
    } on ChatApiException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return null;
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return null;
    }
  }

  Future<String?> _sendStreamingMessage(
    String message, {
    XFile? attachment,
  }) async {
    final generation = ++_streamGeneration;
    final streamedAssistantId =
        'local-assistant-${DateTime.now().microsecondsSinceEpoch}';

    try {
      final api = ref.read(chatApiProvider);
      final financialContext = await _financialContext(message);
      await for (final event in api.streamMessage(
        message,
        conversationId: state.conversationId,
        attachment: attachment,
        financialContext: financialContext,
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
                ? _messagesFromApiResponse(response)
                : _messagesWithClarityActions(
                    _messagesWithStreamingStopped(state.messages),
                    response.memoryChanges,
                  ),
            isLoading: false,
            clearError: true,
          );
          await _refreshSavedMemoryOverviewIfNeeded(response.memoryChanges);
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
          errorMessage: error.message,
          messages: _messagesWithStreamingStopped(state.messages),
        );
      }
      return null;
    } on Object catch (error) {
      if (generation == _streamGeneration) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
          messages: _messagesWithStreamingStopped(state.messages),
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _financialContext(String message) async {
    if (!shouldAttachAssistantFinancialContext(message)) {
      return null;
    }
    final service = ref.read(assistantFinancialContextServiceProvider);
    if (service == null) {
      return AssistantFinancialContextService.unavailableSummary(
        source: 'mobile_financial_context_service',
        message:
            'Financial context is not available in this app session. Tell the user the financial data cannot be loaded right now.',
      );
    }
    try {
      return await service.buildSummary();
    } on Object catch (error) {
      return AssistantFinancialContextService.degradedSummary(
        source: 'mobile_financial_context_service',
        error: error,
      );
    }
  }

  Future<void> _refreshSavedMemoryOverviewIfNeeded(
    Map<String, dynamic>? memoryChanges,
  ) async {
    if (!_memoryChangesRequireSavedOverviewRefresh(memoryChanges)) {
      return;
    }
    await ref.read(memoryProvider.notifier).loadSavedOverview();
  }

  bool _memoryChangesRequireSavedOverviewRefresh(
    Map<String, dynamic>? memoryChanges,
  ) {
    if (memoryChanges == null) {
      return false;
    }
    for (final key in const ['created', 'updated', 'archived', 'merged']) {
      final value = memoryChanges[key];
      if (value is num && value > 0) {
        return true;
      }
    }
    final records = memoryChanges['records'];
    return records is List &&
        records.any((record) {
          if (record is! Map) {
            return false;
          }
          return const {
            'direct_saved',
            'direct_updated',
            'archived_superseded',
            'direct_archived',
          }.contains(record['action']);
        });
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

  ChatMessage _messageFromApi(ChatApiMessage message) => message.toDomain();

  List<ChatMessage> _messagesFromApiResponse(ChatApiResponse response) {
    return _messagesFromApiMessages(
      response.messages,
      memoryChanges: response.memoryChanges,
    );
  }

  List<ChatMessage> _messagesFromApiMessages(
    List<ChatApiMessage> messages, {
    Map<String, dynamic>? memoryChanges,
  }) {
    final mapped = messages.map(_messageFromApi).toList(growable: false);
    return _messagesWithClarityActions(mapped, memoryChanges);
  }

  List<ChatMessage> _messagesWithClarityActions(
    List<ChatMessage> messages,
    Map<String, dynamic>? memoryChanges,
  ) {
    final clarityActions = clarityActionCardsFromMemoryChanges(memoryChanges);
    if (clarityActions.isEmpty || messages.isEmpty) {
      return List.unmodifiable(messages);
    }

    final updated = [...messages];
    for (var index = updated.length - 1; index >= 0; index--) {
      if (updated[index].role == ChatMessageRole.assistant) {
        updated[index] = updated[index].copyWith(
          clarityActions: clarityActions,
        );
        return List.unmodifiable(updated);
      }
    }
    return List.unmodifiable(updated);
  }

  void _updateClarityAction(
    String actionId,
    ClarityActionCard Function(ClarityActionCard current) update,
  ) {
    final updatedMessages = [
      for (final message in state.messages)
        if (message.clarityActions.any((action) => action.id == actionId))
          message.copyWith(
            clarityActions: [
              for (final action in message.clarityActions)
                action.id == actionId ? update(action) : action,
            ],
          )
        else
          message,
    ];
    state = state.copyWith(messages: List.unmodifiable(updatedMessages));
  }
}
