// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerStreamingCaptureResult on VoiceCallController {
  Future<void> _handleStreamingCaptureResult(
    StreamingUtteranceCaptureResult captureResult, {
    required int generation,
    required int listenEpoch,
    StreamingVoiceSession? session,
  }) async {
    if (!_isCurrentCall(generation) ||
        listenEpoch != _streamingListenEpoch ||
        !state.isCallActive) {
      if (session != null && !identical(_activeStreamingSession, session)) {
        unawaited(session.endSession());
      }
      return;
    }

    _voiceTrace.record(
      event: 'capture.end',
      reason: captureResult.endKind.name,
      turnId: '$_streamingTurnSequence',
      fromPhase: state.phase.name,
      toPhase: state.phase.name,
    );

    switch (captureResult.endKind) {
      case StreamingCaptureEndKind.vadSilence:
        await _handleVadSilenceCaptureEnd(
          captureResult,
          generation: generation,
          listenEpoch: listenEpoch,
        );
        return;
      case StreamingCaptureEndKind.maxDuration:
        await _rollCaptureAfterMaxDuration(generation);
        return;
      case StreamingCaptureEndKind.aborted:
      case StreamingCaptureEndKind.cancelled:
      case StreamingCaptureEndKind.noSpeech:
        await _handleNonVadCaptureEnd(
          captureResult,
          generation: generation,
          listenEpoch: listenEpoch,
        );
        return;
    }
  }

  Future<void> _handleVadSilenceCaptureEnd(
    StreamingUtteranceCaptureResult captureResult, {
    required int generation,
    required int listenEpoch,
  }) async {
    _markVadSilenceReached(source: 'capture.vadSilence');
    // Diagnostic: local amplitude endpoint must not submit — keep listening.
    if (_manualEndpointOnly) {
      debugPrint(
        'rex_voice_authority vad_silence_roll_manual_only '
        '${VoiceVadTelemetry.instance.summaryLine()}',
      );
      _voiceTrace.record(
        event: 'vad.would_submit',
        reason: 'suppressed_manual_endpoint_only',
        turnId: '$_streamingTurnSequence',
        fromPhase: state.phase.name,
        toPhase: state.phase.name,
      );
      await _rollCaptureAfterMaxDuration(generation);
      return;
    }
    if (!captureResult.hasSpeech) {
      if (state.phase == VoiceCallPhase.thinking ||
          state.phase == VoiceCallPhase.speaking) {
        return;
      }
      if (listenEpoch != _streamingListenEpoch) {
        return;
      }
      if (_holdUtteranceEndForLifecycle) {
        _restartListenAfterLifecycleHold = true;
        return;
      }
      if (_streamingTurnFinalizedSequence == _streamingTurnSequence ||
          _speechFinalGraceTimer != null) {
        return;
      }
      _recoverFromEmptyVoiceTurn(voiceL10n.voiceFailureDidNotCatch);
      return;
    }

    if (state.phase == VoiceCallPhase.listening &&
        listenEpoch == _streamingListenEpoch) {
      state = state.copyWith(isCapturingSpeech: false);
      if (_holdUtteranceEndForLifecycle) {
        _restartListenAfterLifecycleHold = true;
        return;
      }
      _endTurnFromLocalEndpoint(
        generation,
        reason: VoiceTurnFinalizeReason.vadSilence,
        recoverIfEmpty: false,
      );
      if (_streamingTurnFinalizedSequence != _streamingTurnSequence) {
        _armSpeechFinalGraceAfterCapture(generation, listenEpoch);
      }
    }
  }

  Future<void> _rollCaptureAfterMaxDuration(int generation) async {
    // Max-duration is not conversational silence — keep the same logical turn.
    if (state.phase != VoiceCallPhase.listening || state.isMuted) {
      return;
    }
    _voiceTrace.record(
      event: 'capture.max_duration_roll',
      reason: VoiceTurnFinalizeReason.maxDurationRollover.code,
      turnId: '$_streamingTurnSequence',
      fromPhase: state.phase.name,
      toPhase: state.phase.name,
    );
    debugPrint('rex_voice_authority max_duration_roll_same_turn');
    _cancelListeningEndpointTimeout();
    _cancelSpeechFinalGrace();
    state = state.copyWith(isCapturingSpeech: false, clearError: true);
    _startListeningCyclePreservingTranscript(generation);
  }

  Future<void> _handleNonVadCaptureEnd(
    StreamingUtteranceCaptureResult captureResult, {
    required int generation,
    required int listenEpoch,
  }) async {
    if (state.phase == VoiceCallPhase.thinking ||
        state.phase == VoiceCallPhase.speaking) {
      return;
    }
    if (listenEpoch != _streamingListenEpoch) {
      return;
    }
    if (_streamingTurnFinalizedSequence == _streamingTurnSequence ||
        _speechFinalGraceTimer != null) {
      return;
    }
    if (_holdUtteranceEndForLifecycle) {
      _restartListenAfterLifecycleHold = true;
      return;
    }
    // Mic heard speech then stream died — keep bubble, restart listen.
    // Empty cancel with a stuck transcript still uses chat-fallback recover.
    if (captureResult.hasSpeech) {
      _restartListenAfterLifecycleHold = true;
      _cancelListeningEndpointTimeout();
      _cancelSpeechFinalGrace();
      await _recoverListenCycleAfterLifecycleHold();
      return;
    }
    _recoverFromEmptyVoiceTurn(voiceL10n.voiceFailureDidNotCatch);
  }
}
