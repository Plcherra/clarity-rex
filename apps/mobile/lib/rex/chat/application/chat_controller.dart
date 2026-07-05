import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/core/l10n/friendly_service_error.dart';
import 'package:clarity/features/dashboard/application/dashboard_deep_link_navigation.dart';
import 'package:clarity/features/dashboard/domain/dashboard_insight_anchor.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
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

part 'chat_controller_actions.dart';
part 'chat_controller_send.dart';
part 'chat_controller_context.dart';
part 'chat_controller_voice.dart';

final chatApiProvider = Provider<ChatApi>((ref) => ChatApi());

final chatProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends Notifier<ChatState> {
  int _streamGeneration = 0;

  String localizedError(Object error) {
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
    final clarityActions = clarityActionCardsFromMemoryChanges(memoryChanges);
    if (messages.isNotEmpty) {
      state = state.copyWith(
        conversationId: conversationId,
        messages: _messagesWithAssistantExtras(
          mergeBackendMessagesPreservingLocalVoice(
            local: state.messages,
            backend: _messagesFromApiMessages(messages),
          ),
          memoryChanges: memoryChanges,
        ),
        isLoading: false,
        clearError: true,
      );
      unawaited(_refreshSavedMemoryOverviewIfNeeded(memoryChanges));
      unawaited(_refreshGoalsOverviewIfNeeded(memoryChanges));
      return;
    }

    state = state.copyWith(
      conversationId: conversationId,
      isLoading: false,
      clearError: true,
    );

    final fallbackText = fallbackAssistantResponse?.trim() ?? '';
    if (fallbackText.isNotEmpty || clarityActions.isNotEmpty) {
      addMessage(
        ChatMessage(
          id: 'local-assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatMessageRole.assistant,
          content: fallbackText,
          timestamp: DateTime.now(),
          clarityActions: clarityActions,
        ),
      );
    }
    unawaited(_refreshSavedMemoryOverviewIfNeeded(memoryChanges));
    unawaited(_refreshGoalsOverviewIfNeeded(memoryChanges));
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
      await _hydratePendingWriteProposal(conversationId);
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: localizedError(error));
    }
  }

  Future<void> _hydratePendingWriteProposal(String conversationId) async {
    if (pendingClarityActions(state.messages).isNotEmpty) {
      return;
    }

    try {
      final memoryChanges = await ref
          .read(conversationApiProvider)
          .getPendingWriteProposal(conversationId);
      if (memoryChanges == null ||
          clarityActionCardsFromMemoryChanges(memoryChanges).isEmpty) {
        return;
      }
      state = state.copyWith(
        messages: _messagesWithAssistantExtras(
          state.messages,
          memoryChanges: memoryChanges,
        ),
      );
    } on Object {
      // Pending write hydration is best-effort when reopening a conversation.
    }
  }

  void cancelStreaming() {
    _streamGeneration++;
    state = state.copyWith(
      isLoading: false,
      messages: _messagesWithStreamingStopped(state.messages),
    );
  }

  Future<void> executeClarityAction(ClarityActionCard action) =>
      _runExecuteClarityAction(action);

  void dismissClarityAction(ClarityActionCard action) =>
      _runDismissClarityAction(action);

  Future<String?> sendMessageForAssistantResponse(
    String content, {
    XFile? attachment,
    bool stream = true,
    Map<String, dynamic>? writeConfirmation,
  }) =>
      _runSendMessageForAssistantResponse(
        content,
        attachment: attachment,
        stream: stream,
        writeConfirmation: writeConfirmation,
      );

  Map<String, dynamic>? writeConfirmationForAffirmation(String message) =>
      _writeConfirmationForTypedAffirmation(message);
}
