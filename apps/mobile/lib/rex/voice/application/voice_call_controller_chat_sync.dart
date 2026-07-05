// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerChatSync on VoiceCallController {
  void _resetActiveVoiceMessageLocalId() {
    _activeVoiceMessageLocalId = null;
  }

  void _resetPendingUtteranceTranscript() {
    _pendingUtteranceTranscript = null;
  }

  String _ensureActiveVoiceMessageLocalId() {
    return _activeVoiceMessageLocalId ??=
        'local-voice-${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _hasActiveVoiceMessageInChat() {
    final localId = _activeVoiceMessageLocalId;
    if (localId == null) {
      return false;
    }
    return ref
        .read(chatProvider)
        .messages
        .any((message) => message.id == localId);
  }

  void _syncInterimVoiceTranscriptToChat(String content) {
    final text = content.trim();
    if (text.isEmpty) {
      return;
    }

    ref.read(chatProvider.notifier).upsertVoiceUserMessage(
      localId: _ensureActiveVoiceMessageLocalId(),
      content: text,
    );
  }

  void _finalizeVoiceTranscriptInChat({String? finalTranscript}) {
    final text = (finalTranscript ?? _transcriptBuffer.visible).trim();
    if (text.isEmpty) {
      _removeActiveVoiceUserMessage();
      return;
    }

    final localId = _ensureActiveVoiceMessageLocalId();
    ref.read(chatProvider.notifier).finalizeVoiceUserMessage(
      localId: localId,
      content: text,
    );
    ref.read(chatProvider.notifier).removeStaleLocalVoiceUserMessages(
      keepLocalId: localId,
      finalContent: text,
    );
  }

  void _removeActiveVoiceUserMessage() {
    final localId = _activeVoiceMessageLocalId;
    if (localId == null) {
      return;
    }

    ref.read(chatProvider.notifier).removeVoiceUserMessage(localId);
    _resetActiveVoiceMessageLocalId();
  }

  void _finalizeStreamingTurn({
    required String transcript,
    required StreamingVoiceSession session,
    required int turnSequence,
  }) {
    final text = transcript.trim();
    if (text.isEmpty || !state.isCallActive) {
      return;
    }

    _pendingUtteranceTranscript = text;
    startThinking(finalTranscript: text);
    _sendStreamingUtteranceEndIfNeeded(
      session,
      turnSequence,
      transcript: text,
    );
  }
}
