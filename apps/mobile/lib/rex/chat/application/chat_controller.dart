import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/core/l10n/friendly_service_error.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/features/dashboard/application/dashboard_deep_link_navigation.dart';
import 'package:clarity/features/dashboard/domain/dashboard_insight_anchor.dart';
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
import 'package:clarity/rex/chat/presentation/widgets/clarity_action_cards_strip.dart';
import 'package:clarity/rex/data/financial_context_service.dart';
import 'package:clarity/rex/memory/application/memory_controller.dart';
import 'package:clarity/rex/accountability/application/accountability_controller.dart';

export 'package:clarity/rex/chat/application/chat_state.dart';

final chatApiProvider = Provider<ChatApi>((ref) => ChatApi());

final chatProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends Notifier<ChatState> {
  int _streamGeneration = 0;

  String _localizedError(Object error) {
    return friendlyServiceError(
      lookupForLocale(ref.read(localeControllerProvider).locale),
      error,
    );
  }

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
    if (_isChatConfirmedWriteAction(action.action)) {
      await _confirmPlanSave(action);
      return;
    }

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
          content: ref.read(actionResultMessageFormatterProvider)(
            action.action,
            result.result,
          ),
          timestamp: DateTime.now(),
        ),
      );
    } on ClarityActionsApiException catch (error) {
      _updateClarityAction(
        action.id,
        (current) =>
            current.copyWith(status: 'failed', errorMessage: _localizedError(error)),
      );
    } on Object catch (error) {
      _updateClarityAction(
        action.id,
        (current) =>
            current.copyWith(status: 'failed', errorMessage: _localizedError(error)),
      );
    }
  }

  void dismissClarityAction(ClarityActionCard action) {
    if (_isChatConfirmedWriteAction(action.action)) {
      unawaited(_rejectPlanSave(action));
      return;
    }

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
      state = state.copyWith(isLoading: false, errorMessage: _localizedError(error));
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
      state = state.copyWith(isLoading: false, errorMessage: _localizedError(error));
      return null;
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: _localizedError(error));
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
          errorMessage: _localizedError(error),
          messages: _messagesWithStreamingStopped(state.messages),
        );
      }
      return null;
    } on Object catch (error) {
      if (generation == _streamGeneration) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: _localizedError(error),
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

  DashboardInsightAnchor? _dashboardLinkAnchor(
    String message,
    Map<String, dynamic>? financialContext,
  ) {
    if (financialContext == null ||
        !shouldAttachAssistantFinancialContext(message)) {
      return null;
    }
    return resolveDashboardInsightAnchor(message);
  }

  Future<void> _refreshSavedMemoryOverviewIfNeeded(
    Map<String, dynamic>? memoryChanges,
  ) async {
    if (!_memoryChangesRequireSavedOverviewRefresh(memoryChanges)) {
      return;
    }
    await ref.read(memoryProvider.notifier).loadSavedOverview();
  }

  Future<void> _refreshGoalsOverviewIfNeeded(
    Map<String, dynamic>? memoryChanges,
  ) async {
    if (!_memoryChangesRequireGoalsRefresh(memoryChanges)) {
      return;
    }
    await ref.read(accountabilityProvider.notifier).loadOverview();
  }

  bool _memoryChangesRequireGoalsRefresh(Map<String, dynamic>? memoryChanges) {
    if (memoryChanges == null) {
      return false;
    }
    for (final key in const ['created', 'updated', 'merged']) {
      final value = memoryChanges[key];
      if (value is num && value > 0) {
        return true;
      }
    }
    final proposals = memoryChanges['write_proposals'] ?? memoryChanges['plan_save_proposals'];
    if (proposals is List) {
      for (final proposal in proposals) {
        if (proposal is! Map) {
          continue;
        }
        final kind = proposal['write_kind']?.toString() ?? '';
        if ({'plan', 'milestone', 'commitment', 'open_thread', 'update_plan', 'update_milestone', 'update_commitment'}
            .contains(kind)) {
          return proposal['status'] == 'applied';
        }
      }
    }
    return false;
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
    final proposals = memoryChanges['write_proposals'];
    if (proposals is List) {
      for (final proposal in proposals) {
        if (proposal is Map && proposal['status'] == 'applied') {
          final kind = proposal['write_kind']?.toString() ?? '';
          if (kind == 'memory' || kind.isEmpty) {
            return true;
          }
        }
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

  List<ChatMessage> _messagesFromApiResponse(
    ChatApiResponse response, {
    DashboardInsightAnchor? dashboardLink,
  }) {
    return _mergePendingAttachments(
      state.messages,
      _messagesWithAssistantExtras(
        _messagesFromApiMessages(
          response.messages,
          memoryChanges: response.memoryChanges,
        ),
        memoryChanges: response.memoryChanges,
        dashboardLink: dashboardLink,
      ),
    );
  }

  List<ChatMessage> _mergePendingAttachments(
    List<ChatMessage> previousMessages,
    List<ChatMessage> mappedMessages,
  ) {
    final pendingAttachments = [
      for (final message in previousMessages)
        if (message.role == ChatMessageRole.user && message.hasNamedAttachment)
          (
            content: message.content,
            localPath: message.attachmentLocalPath,
            previewBytes: message.attachmentPreviewBytes,
            name: message.attachmentName,
          ),
    ];
    if (pendingAttachments.isEmpty) {
      return mappedMessages;
    }

    var pendingIndex = pendingAttachments.length - 1;
    final merged = mappedMessages.toList(growable: true);
    for (var index = merged.length - 1;
        index >= 0 && pendingIndex >= 0;
        index--) {
      final message = merged[index];
      if (message.role != ChatMessageRole.user || message.hasNamedAttachment) {
        continue;
      }

      final pending = pendingAttachments[pendingIndex];
      merged[index] = message.copyWith(
        attachmentLocalPath: pending.localPath,
        attachmentPreviewBytes: pending.previewBytes,
        attachmentName: pending.name,
      );
      pendingIndex--;
    }

    return List.unmodifiable(merged);
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

  List<ChatMessage> _messagesFromApiMessages(
    List<ChatApiMessage> messages, {
    Map<String, dynamic>? memoryChanges,
  }) {
    return messages.map(_messageFromApi).toList(growable: false);
  }

  List<ChatMessage> _messagesWithAssistantExtras(
    List<ChatMessage> messages, {
    Map<String, dynamic>? memoryChanges,
    DashboardInsightAnchor? dashboardLink,
  }) {
    final clarityActions = clarityActionCardsFromMemoryChanges(memoryChanges);
    if (clarityActions.isEmpty && dashboardLink == null) {
      return List.unmodifiable(messages);
    }

    final updated = [...messages];
    for (var index = updated.length - 1; index >= 0; index--) {
      if (updated[index].role == ChatMessageRole.assistant) {
        updated[index] = updated[index].copyWith(
          clarityActions: clarityActions.isEmpty
              ? updated[index].clarityActions
              : clarityActions,
          dashboardLinkAnchor:
              dashboardLink ?? updated[index].dashboardLinkAnchor,
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

  bool _isChatConfirmedWriteAction(String action) {
    return action == 'save_plan' ||
        action == 'save_plan_milestone' ||
        action == 'save_commitment' ||
        action == 'save_open_thread' ||
        action == 'save_memory' ||
        action == 'update_plan' ||
        action == 'update_plan_milestone' ||
        action == 'update_commitment' ||
        action == 'save_entity_event';
  }

  Map<String, dynamic>? writeConfirmationForAffirmation(String message) {
    return _writeConfirmationForTypedAffirmation(message);
  }

  Map<String, dynamic>? _writeConfirmationForTypedAffirmation(String message) {
    final normalized = message.trim().toLowerCase();
    const affirmations = {
      'yes',
      'yes please',
      'yep',
      'yeah',
      'sure',
      'please',
      'please do',
      'do it',
      'save it',
      'save that',
      'save this',
    };
    if (!affirmations.contains(normalized)) {
      return null;
    }
    final pending = pendingClarityActions(state.messages);
    if (pending.length != 1 || !pending.first.canConfirm) {
      return null;
    }
    return _writeConfirmationPayload(pending.first);
  }

  Map<String, dynamic> _writeConfirmationPayload(ClarityActionCard action) {
    final payload = <String, dynamic>{'proposal_id': action.id};
    if (action.hasEditableFields) {
      final edits = <String, dynamic>{};
      if (action.editableFields.contains('title') && action.title != null) {
        edits['title'] = action.title;
      }
      if (action.editableFields.contains('body') && action.body != null) {
        edits['body'] = action.body;
      }
      if (edits.isNotEmpty) {
        payload['edits'] = edits;
      }
    }
    return payload;
  }

  Future<void> _confirmPlanSave(ClarityActionCard action) async {
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(status: 'applying', clearError: true),
    );
    final response = await sendMessageForAssistantResponse(
      'Yes',
      stream: false,
      writeConfirmation: _writeConfirmationPayload(action),
    );
    if (response == null) {
      _updateClarityAction(
        action.id,
        (current) => current.copyWith(
          status: 'failed',
          errorMessage: 'Could not confirm the plan save.',
        ),
      );
      return;
    }
    _syncClarityActionFromMessages(action.id);
  }

  void _syncClarityActionFromMessages(String actionId) {
    for (final message in state.messages) {
      for (final action in message.clarityActions) {
        if (action.id != actionId) {
          continue;
        }
        _updateClarityAction(actionId, (_) => action);
        return;
      }
    }
    _updateClarityAction(
      actionId,
      (current) => current.copyWith(status: 'applied', clearError: true),
    );
  }

  Future<void> _rejectPlanSave(ClarityActionCard action) async {
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(status: 'applying', clearError: true),
    );
    final response = await sendMessageForAssistantResponse('No', stream: false);
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(
        status: response == null ? 'failed' : 'dismissed',
        clearError: true,
      ),
    );
  }
}
