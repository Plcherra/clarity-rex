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

    // Screenshot / route blip: mic dies before AppLifecycle inactive. Never
    // treat stream death as a conversational endpoint.
    if (!captureResult.endedByVoiceEndpoint) {
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
      _endTurnFromLocalEndpoint(generation, recoverIfEmpty: false);
      if (_streamingTurnFinalizedSequence != _streamingTurnSequence) {
        _armSpeechFinalGraceAfterCapture(generation, listenEpoch);
      }
    }
  }
}
