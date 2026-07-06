// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerChatSync on VoiceCallController {
  void _beginVoiceTurn(int turnSequence) {
    _transcriptBuffer.clear();
    _activeVoiceMessageLocalId = 'local-voice-$turnSequence';
    _beginVoiceTurnTiming(turnSequence);
  }

  void _resetActiveVoiceMessageLocalId() {
    _activeVoiceMessageLocalId = null;
  }

  void _resetPendingUtteranceTranscript() {
    _pendingUtteranceTranscript = null;
  }

  String _ensureActiveVoiceMessageLocalId() {
    return _activeVoiceMessageLocalId ??=
        'local-voice-$_streamingTurnSequence';
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
    final text = VoiceTranscriptBuffer.preferFullest([
      if (finalTranscript != null) finalTranscript,
      _transcriptBuffer.visible,
    ]).trim();
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

  void _endTurnFromLocalEndpoint(
    int generation, {
    String? preferredTranscript,
    bool recoverIfEmpty = false,
  }) {
    if (!_isCurrentCall(generation) ||
        !state.isCallActive ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted ||
        _pausedForSaveConfirmation ||
        _hasPendingSaveConfirmation()) {
      return;
    }
    if (_streamingTurnFinalizedSequence == _streamingTurnSequence) {
      return;
    }
    final session = _activeStreamingSession;
    if (session == null) {
      return;
    }

    final transcript = VoiceTranscriptBuffer.preferFullest([
      if (preferredTranscript != null) preferredTranscript,
      _transcriptBuffer.visible,
    ]).trim();
    if (transcript.isEmpty) {
      if (recoverIfEmpty) {
        _recoverFromEmptyVoiceTurn('I did not catch that. I am listening again.');
      }
      return;
    }

    _finalizeStreamingTurn(
      transcript: transcript,
      session: session,
      turnSequence: _streamingTurnSequence,
    );
  }

  void _finalizeStreamingTurn({
    required String transcript,
    required StreamingVoiceSession session,
    required int turnSequence,
  }) {
    if (_streamingTurnFinalizedSequence == turnSequence) {
      return;
    }

    final text = transcript.trim();
    if (text.isEmpty || !state.isCallActive) {
      return;
    }

    _streamingTurnFinalizedSequence = turnSequence;
    _pendingUtteranceTranscript = text;
    _markVoiceTurnFinalize(turnSequence);
    startThinking(finalTranscript: text);
    _sendStreamingUtteranceEndIfNeeded(
      session,
      turnSequence,
      transcript: text,
    );
  }
}
