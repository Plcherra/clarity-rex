// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerChatSync on VoiceCallController {
  void _beginVoiceTurn(int turnSequence) {
    _transcriptBuffer.clear();
    _activeVoiceMessageLocalId = 'local-voice-$turnSequence';
    _pendingUtteranceTranscript = null;
    // Fresh listen cycle may accept speech_final; do not inherit suppress from
    // a prior finalize → empty_audio → soft-recover path.
    _suppressStaleSpeechFinal = false;
    state = state.copyWith(clearCurrentTranscript: true);
    _beginVoiceTurnTiming(turnSequence);
  }

  void _rememberCompletedUtterance(String transcript) {
    final text = transcript.trim();
    if (text.isEmpty) {
      return;
    }
    _lastCompletedUtteranceTranscript = text;
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

  void _finalizeVoiceTranscriptInChat({
    String? finalTranscript,
    bool rememberCompleted = false,
    bool stripPriorUtterance = true,
  }) {
    final merged = VoiceTranscriptBuffer.preferFullest([
      ?finalTranscript,
      _transcriptBuffer.visible,
    ]);
    final text = (stripPriorUtterance
            ? VoiceTranscriptBuffer.stripLeadingUtterance(
                merged,
                priorUtterance: _lastCompletedUtteranceTranscript,
              )
            : merged)
        .trim();
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
    if (rememberCompleted) {
      _rememberCompletedUtterance(text);
    }
  }

  void _removeActiveVoiceUserMessage({bool evenIfFinalized = false}) {
    final localId = _activeVoiceMessageLocalId;
    if (localId == null) {
      return;
    }

    ref.read(chatProvider.notifier).removeVoiceUserMessage(
      localId,
      evenIfFinalized: evenIfFinalized,
    );
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
        state.isMuted) {
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
      ?preferredTranscript,
      _transcriptBuffer.visible,
    ]).trim();
    if (transcript.isEmpty) {
      if (recoverIfEmpty) {
        _recoverFromEmptyVoiceTurn(voiceL10n.voiceFailureDidNotCatch);
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
    _suppressStaleSpeechFinal = true;
    _cancelListeningEndpointTimeout();
    _cancelSpeechFinalGrace();
    _markVoiceTurnFinalize(turnSequence);
    startThinking(finalTranscript: text);
    _sendStreamingUtteranceEndIfNeeded(
      session,
      turnSequence,
      transcript: text,
    );
    // Route audio out to the speaker while Rex thinks, whichever endpoint closed
    // the utterance, so the first assistant words are never clipped or earpieced.
    unawaited(_preparePlaybackAudioSession());
  }
}
