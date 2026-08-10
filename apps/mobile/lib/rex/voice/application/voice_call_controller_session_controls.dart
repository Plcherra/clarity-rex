// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerSessionControls on VoiceCallController {
  void setMuted(bool isMuted) {
    if (!state.isCallActive) {
      return;
    }

    state = state.copyWith(isMuted: isMuted);
    if (_isUsingNativeVoice) {
      unawaited(_nativeVoiceSessionService.setMuted(isMuted));
      return;
    }
    if (isMuted) {
      _callGeneration++;
      _cancelThinkingTimeout();
      _cancelNoSpeechTimeout();
      unawaited(_stopInterimTranscription());
      unawaited(_captureService.cancel());
      unawaited(_streamingCaptureService.cancel());
      _stopBargeInMonitoring();
      final streamingSession = _activeStreamingSession;
      _activeStreamingSession = null;
      _activeStreamingEventsTask = null;
      streamingSession?.interrupt();
      unawaited(_streamingPlaybackQueue.cancel());
      unawaited(streamingSession?.endSession());
    } else if (state.phase == VoiceCallPhase.listening) {
      _startListeningCycle(++_callGeneration);
    }
  }

  void toggleMuted() {
    setMuted(!state.isMuted);
  }

  void fail(String message) {
    _callGeneration++;
    _isAwaitingFollowUpSpeech = false;
    _emptyVoiceTurnRecoveryCount = 0;
    _awaitingManualEndpointSubmit = false;
    _cancelThinkingTimeout();
    _cancelNoSpeechTimeout();
    unawaited(_stopInterimTranscription());
    _stopNativeVoiceSession();
    unawaited(_captureService.cancel());
    unawaited(_streamingCaptureService.cancel());
    _stopBargeInMonitoring();
    final streamingSession = _activeStreamingSession;
    _activeStreamingSession = null;
    _activeStreamingEventsTask = null;
    streamingSession?.interrupt();
    unawaited(_streamingPlaybackQueue.cancel());
    unawaited(streamingSession?.endSession());
    unawaited(_playbackService.stop());
    unawaited(_backgroundVoiceService.stop());
    unawaited(_audioSessionService.setActive(false));
    state = state.copyWith(
      phase: VoiceCallPhase.failed,
      isCapturingSpeech: false,
      errorMessage: message,
      callEndedAt: ref.read(voiceCallNowProvider)(),
      clearCurrentTranscript: true,
    );
    _clearVisibleTranscript();
  }

  /// Red stop control: while listening, submit the current utterance once.
  /// Otherwise end the whole call (previous behavior).
  Future<void> endTurnOrCall() async {
    if (!state.isCallActive) {
      return;
    }
    if (state.phase == VoiceCallPhase.listening && !state.isMuted) {
      final submitted = await submitManualEndTurn();
      if (submitted) {
        return;
      }
      // Never hang up when speech is still on screen / in the buffer — that
      // looked like "stop does nothing" / wiped the turn without sending.
      final leftover = _manualStopTranscriptCandidate();
      if (leftover.isNotEmpty) {
        debugPrint(
          'rex_voice_authority red_stop_kept_listening '
          'chars=${leftover.length}',
        );
        _voiceTrace.record(
          event: 'manual_stop.kept_listening',
          reason: 'submit_failed_with_transcript',
          turnId: '$_streamingTurnSequence',
          fromPhase: state.phase.name,
          toPhase: state.phase.name,
        );
        return;
      }
    }
    await endCall();
  }

  String _manualStopTranscriptCandidate() {
    final chatInterim =
        ref.read(chatProvider.notifier).latestInterimVoiceUserContent();
    return VoiceTranscriptBuffer.stripLeadingUtterance(
      VoiceTranscriptBuffer.preferFullest([
        _transcriptBuffer.visible,
        state.currentTranscript,
        ?_pendingUtteranceTranscript,
        ?chatInterim,
      ]),
      priorUtterance: _lastCompletedUtteranceTranscript,
    ).trim();
  }

  /// Submit the in-progress transcript via the single finalize authority.
  /// Returns true when a turn was finalized.
  Future<bool> submitManualEndTurn() async {
    if (!state.isCallActive ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return false;
    }
    final generation = _callGeneration;
    final transcript = _manualStopTranscriptCandidate();
    if (transcript.isEmpty) {
      debugPrint('rex_voice_authority red_stop_empty_transcript');
      _voiceTrace.record(
        event: 'manual_stop.rejected',
        reason: 'empty_transcript',
        turnId: '$_streamingTurnSequence',
        fromPhase: state.phase.name,
        toPhase: state.phase.name,
      );
      return false;
    }

    // Rehydrate buffer from the authority string so chat-interim recovery
    // still finalizes one coherent bubble.
    _transcriptBuffer.clear();
    _transcriptBuffer.appendFinal(transcript);
    state = state.copyWith(
      currentTranscript: transcript,
      isCapturingSpeech: false,
    );

    _voiceTrace.record(
      event: 'manual_stop',
      reason: VoiceTurnFinalizeReason.manualStop.code,
      turnId: '$_streamingTurnSequence',
      fromPhase: state.phase.name,
      toPhase: VoiceCallPhase.thinking.name,
    );
    debugPrint(VoiceVadTelemetry.instance.summaryLine());
    debugPrint(
      'rex_voice_authority red_stop_submit chars=${transcript.length} '
      'ws=${_activeStreamingSession != null}',
    );
    _voiceTrace.record(
      event: 'vad_telemetry',
      reason: VoiceVadTelemetry.instance.summaryLine(),
      turnId: '$_streamingTurnSequence',
      fromPhase: state.phase.name,
      toPhase: state.phase.name,
    );

    _cancelListeningEndpointTimeout();
    _cancelSpeechFinalGrace();
    _pendingUtteranceTranscript = transcript;

    // No live WS (common physical failure): red stop must still submit via
    // chat+TTS. `_endTurnFromLocalEndpoint` no-ops when session is null.
    if (_activeStreamingSession == null) {
      final submitted = _completeStreamingTurnViaChatFallback(force: true);
      _awaitingManualEndpointSubmit = false;
      await _streamingCaptureService.cancel();
      await _captureService.cancel();
      unawaited(_stopInterimTranscription());
      return submitted;
    }

    // Finalize first so a cancelled capture end cannot divert to empty-turn
    // recovery. Then stop the mic cycle — do not wait for VAD silence.
    _endTurnFromLocalEndpoint(
      generation,
      reason: VoiceTurnFinalizeReason.manualStop,
      preferredTranscript: transcript,
    );
    final finalized =
        _streamingTurnFinalizedSequence == _streamingTurnSequence;
    _awaitingManualEndpointSubmit = false;
    await _streamingCaptureService.cancel();
    await _captureService.cancel();
    return finalized;
  }

  Future<void> endCall() async {
    if (!state.canEndCall) {
      return;
    }

    _callGeneration++;
    _isAwaitingFollowUpSpeech = false;
    _emptyVoiceTurnRecoveryCount = 0;
    _awaitingManualEndpointSubmit = false;
    _cancelThinkingTimeout();
    _cancelNoSpeechTimeout();
    await _releaseVoiceHardware();
    state = state.copyWith(
      phase: VoiceCallPhase.idle,
      isCapturingSpeech: false,
      callEndedAt: ref.read(voiceCallNowProvider)(),
      clearCurrentTranscript: true,
      clearError: true,
    );
    _clearVisibleTranscript();
  }

  Future<void> openVoiceSettings() async {
    await ref.read(microphonePermissionProvider).openSettings();
  }
}
