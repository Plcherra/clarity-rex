// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'chat_controller.dart';

extension ChatControllerActions on ChatController {
  Future<void> _runExecuteClarityAction(ClarityActionCard action) async {
    if (_isChatConfirmedWriteAction(action.action)) {
      await _confirmPlanSave(action);
      return;
    }

    if (!await _ensureOnlineForConfirm(action.id)) {
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
            current.copyWith(status: 'failed', errorMessage: localizedError(error)),
      );
    } on Object catch (error) {
      _updateClarityAction(
        action.id,
        (current) =>
            current.copyWith(status: 'failed', errorMessage: localizedError(error)),
      );
    }
  }

  void _runDismissClarityAction(ClarityActionCard action) {
    if (_isChatConfirmedWriteAction(action.action)) {
      unawaited(_rejectPlanSave(action));
      return;
    }

    _updateClarityAction(
      action.id,
      (current) => current.copyWith(status: 'dismissed', clearError: true),
    );
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
        action == 'save_open_thread' ||
        action == 'save_memory' ||
        action == 'update_plan' ||
        action == 'update_plan_milestone' ||
        action == 'save_entity_event' ||
        action == 'delete_record';
  }

  Future<void> _confirmPlanSave(ClarityActionCard action) async {
    // A28 Saturday guard: one in-flight confirm at a time (single pending_action).
    final alreadyApplying = pendingClarityActions(state.messages).any(
      (other) => other.isApplying && other.id != action.id,
    );
    if (alreadyApplying || state.isLoading) {
      _failClarityActionConfirm(
        action.id,
        errorMessage: _confirmWriteFailedMessage(),
      );
      return;
    }
    // A23 light preflight: fail card with chatErrorNetwork before claiming save.
    if (!await _ensureOnlineForConfirm(action.id)) {
      return;
    }
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(status: 'applying', clearError: true),
    );
    // Always re-send with the same proposal id (retry-safe).
    final writeConfirmation = _writeConfirmationPayload(action);
    final response = await _runSendMessageForAssistantResponse(
      'Yes',
      stream: false,
      writeConfirmation: writeConfirmation,
    );
    if (response == null) {
      ClarityProductEvents.writeConfirmationResult(
        result: 'failed',
        actionType: action.action,
      );
      // Prefer the network/API error already set on chat state; keep it on the
      // card so Retry stays visible without implying the write applied.
      final confirmError = state.errorMessage?.trim();
      _failClarityActionConfirm(
        action.id,
        errorMessage: (confirmError != null && confirmError.isNotEmpty)
            ? confirmError
            : _confirmWriteFailedMessage(),
        clearChatError: true,
      );
      return;
    }
    _syncClarityActionFromMessages(action.id);
    if (response.trim().isNotEmpty) {
      unawaited(ref.read(voiceCallProvider.notifier).speakFollowUp(response));
    }
  }

  String _confirmWriteFailedMessage() {
    return lookupForLocale(
      ref.read(localeControllerProvider).locale,
    ).chatConfirmWriteFailed;
  }

  String _networkUnavailableMessage() {
    return lookupForLocale(
      ref.read(localeControllerProvider).locale,
    ).chatErrorNetwork;
  }

  Future<bool> _ensureOnlineForConfirm(String actionId) async {
    final online = await ref.read(deviceOnlineCheckProvider)();
    if (online) {
      return true;
    }
    _failClarityActionConfirm(
      actionId,
      errorMessage: _networkUnavailableMessage(),
    );
    return false;
  }

  void _failClarityActionConfirm(
    String actionId, {
    required String errorMessage,
    bool clearChatError = false,
  }) {
    _updateClarityAction(
      actionId,
      (current) => current.copyWith(
        status: 'failed',
        errorMessage: errorMessage,
      ),
    );
    if (clearChatError) {
      state = state.copyWith(clearError: true);
    }
  }

  void _syncClarityActionFromMessages(String actionId) {
    ClarityActionCard? terminalEvidence;
    for (final message in state.messages) {
      for (final action in message.clarityActions) {
        if (action.id != actionId) {
          continue;
        }
        // Only trust backend-reported terminal statuses. Never infer success
        // from a missing card or a still-pending/applying local card.
        if (action.isApplied || action.isFailed || action.isDismissed) {
          terminalEvidence = action;
        }
      }
    }
    if (terminalEvidence != null) {
      ClarityProductEvents.writeConfirmationResult(
        result: terminalEvidence.isApplied
            ? 'applied'
            : (terminalEvidence.isDismissed ? 'rejected' : 'failed'),
        actionType: terminalEvidence.action,
      );
      _updateClarityAction(actionId, (_) => terminalEvidence!);
      return;
    }
    ClarityProductEvents.writeConfirmationResult(
      result: 'failed',
      actionType: 'unknown',
    );
    _failClarityActionConfirm(
      actionId,
      errorMessage: _confirmWriteFailedMessage(),
    );
  }

  Future<void> _rejectPlanSave(ClarityActionCard action) async {
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(status: 'applying', clearError: true),
    );
    final response = await _runSendMessageForAssistantResponse('No', stream: false);
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(
        status: response == null ? 'failed' : 'dismissed',
        clearError: true,
      ),
    );
    if (response != null && response.trim().isNotEmpty) {
      unawaited(ref.read(voiceCallProvider.notifier).speakFollowUp(response));
    }
  }
}
