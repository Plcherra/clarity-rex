// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'chat_controller.dart';

extension ChatControllerActions on ChatController {
  Future<void> _runExecuteClarityAction(ClarityActionCard action) async {
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
        action == 'save_entity_event';
  }

  Future<void> _confirmPlanSave(ClarityActionCard action) async {
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(status: 'applying', clearError: true),
    );
    final response = await _runSendMessageForAssistantResponse(
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
    final response = await _runSendMessageForAssistantResponse('No', stream: false);
    _updateClarityAction(
      action.id,
      (current) => current.copyWith(
        status: response == null ? 'failed' : 'dismissed',
        clearError: true,
      ),
    );
  }
}
