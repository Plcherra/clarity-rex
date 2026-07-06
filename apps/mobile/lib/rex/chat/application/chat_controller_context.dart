// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'chat_controller.dart';

extension ChatControllerContext on ChatController {
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
        if ({'plan', 'milestone', 'open_thread', 'update_plan', 'update_milestone'}
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

  List<ChatMessage> _messagesFromApiMessages(
    List<ChatApiMessage> messages,
  ) {
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

    if (clarityActions.isNotEmpty) {
      updated.add(
        ChatMessage(
          id: 'local-assistant-proposal-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatMessageRole.assistant,
          content: '',
          timestamp: DateTime.now(),
          clarityActions: clarityActions,
          dashboardLinkAnchor: dashboardLink,
        ),
      );
    }
    return List.unmodifiable(updated);
  }
}
