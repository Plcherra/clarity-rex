// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerChatSync on VoiceCallController {
  void _beginVoiceTurn(int turnSequence) {
    _transcriptBuffer.clear();
    _activeVoiceMessageLocalId = 'local-voice-$turnSequence';
    _pendingUtteranceTranscript = null;
    _vadSilenceReachedForTurn = false;
    // Keep _suppressStaleSpeechFinal after a prior finalize so in-flight
    // Deepgram speech_final from turn N cannot seed turn N+1. Cleared only by
    // fresh STT evidence (updateTranscript) or empty-turn soft-recover.
    state = state.copyWith(clearCurrentTranscript: true);
    _beginVoiceTurnTiming(turnSequence);
    _voiceTrace.record(
      event: 'turn.begin',
      reason: 'listen_cycle',
      turnId: '$turnSequence',
      fromPhase: state.phase.name,
      toPhase: VoiceCallPhase.listening.name,
    );
  }

  void _markVadSilenceReached({required String source}) {
    _vadSilenceReachedForTurn = true;
    _voiceTrace.record(
      event: 'vad.silence',
      reason: source,
      turnId: '$_streamingTurnSequence',
      fromPhase: state.phase.name,
      toPhase: state.phase.name,
    );
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

  /// Single entry for streaming turn submission. [reason] is mandatory.
  void _endTurnFromLocalEndpoint(
    int generation, {
    required VoiceTurnFinalizeReason reason,
    String? preferredTranscript,
    bool recoverIfEmpty = false,
  }) {
    if (!_isCurrentCall(generation) ||
        !state.isCallActive ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }
    if (_holdUtteranceEndForLifecycle) {
      _restartListenAfterLifecycleHold = true;
      _voiceTrace.record(
        event: 'finalize.blocked',
        reason: 'lifecycle_hold:${reason.code}',
        turnId: '$_streamingTurnSequence',
        fromPhase: state.phase.name,
        toPhase: state.phase.name,
      );
      debugPrint('rex_voice_lifecycle skip_utterance_end_while_held');
      return;
    }
    if (!reason.maySubmitTranscript) {
      _voiceTrace.record(
        event: 'finalize.rejected',
        reason: 'may_not_submit:${reason.code}',
        turnId: '$_streamingTurnSequence',
        fromPhase: state.phase.name,
        toPhase: state.phase.name,
      );
      return;
    }
    // Diagnostic release builds: only red stop (or chat fallback) may submit.
    if (_manualEndpointOnly &&
        reason != VoiceTurnFinalizeReason.manualStop &&
        reason != VoiceTurnFinalizeReason.chatFallback) {
      _voiceTrace.record(
        event: 'finalize.rejected',
        reason: 'manual_endpoint_only:${reason.code}',
        turnId: '$_streamingTurnSequence',
        fromPhase: state.phase.name,
        toPhase: state.phase.name,
      );
      debugPrint(
        'rex_voice_authority manual_endpoint_only reject reason=${reason.code}',
      );
      return;
    }
    if (reason.requiresPriorVadSilence && !_vadSilenceReachedForTurn) {
      _voiceTrace.record(
        event: 'finalize.rejected',
        reason: 'missing_vad:${reason.code}',
        turnId: '$_streamingTurnSequence',
        fromPhase: state.phase.name,
        toPhase: state.phase.name,
      );
      debugPrint('rex_voice_authority reject_without_vad reason=${reason.code}');
      return;
    }
    if (_streamingTurnFinalizedSequence == _streamingTurnSequence) {
      return;
    }
    final session = _activeStreamingSession;
    if (session == null) {
      return;
    }

    final merged = VoiceTranscriptBuffer.preferFullest([
      ?preferredTranscript,
      _transcriptBuffer.visible,
    ]);
    // One authority string for bubble + utterance.end — strip sticky prior here
    // so display and send cannot diverge.
    final transcript = VoiceTranscriptBuffer.stripLeadingUtterance(
      merged,
      priorUtterance: _lastCompletedUtteranceTranscript,
    ).trim();
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
      reason: reason,
    );
  }

  void _finalizeStreamingTurn({
    required String transcript,
    required StreamingVoiceSession session,
    required int turnSequence,
    required VoiceTurnFinalizeReason reason,
  }) {
    if (_streamingTurnFinalizedSequence == turnSequence) {
      return;
    }
    if (!reason.maySubmitTranscript) {
      return;
    }
    if (reason.requiresPriorVadSilence && !_vadSilenceReachedForTurn) {
      return;
    }
    if (_holdUtteranceEndForLifecycle) {
      _restartListenAfterLifecycleHold = true;
      debugPrint('rex_voice_lifecycle skip_finalize_while_held');
      return;
    }

    final text = VoiceTranscriptBuffer.stripLeadingUtterance(
      transcript,
      priorUtterance: _lastCompletedUtteranceTranscript,
    ).trim();
    if (text.isEmpty || !state.isCallActive) {
      return;
    }

    final fromPhase = state.phase.name;
    _streamingTurnFinalizedSequence = turnSequence;
    _pendingUtteranceTranscript = text;
    _suppressStaleSpeechFinal = true;
    _cancelListeningEndpointTimeout();
    _cancelSpeechFinalGrace();
    _markVoiceTurnFinalize(turnSequence);
    _voiceTrace.record(
      event: 'utterance.end',
      reason: reason.code,
      turnId: '$turnSequence',
      fromPhase: fromPhase,
      toPhase: VoiceCallPhase.thinking.name,
    );
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
