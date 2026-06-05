// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerCommands on VoiceCallController {
  void startCapturingSpeech({String transcript = ''}) {
    if (!state.isCallActive) {
      return;
    }

    _isAwaitingFollowUpSpeech = false;
    _cancelNoSpeechTimeout();
    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      currentTranscript: transcript,
      isCapturingSpeech: true,
      clearError: true,
    );
    _armSpeechStartedEndpointTimeout(_callGeneration);
  }

  void updateTranscript(String transcript, {bool isFinal = false}) {
    if (!state.isCallActive) {
      return;
    }

    _isAwaitingFollowUpSpeech = false;
    _cancelNoSpeechTimeout();
    if (isFinal) {
      _transcriptBuffer.appendFinal(transcript);
    } else {
      _transcriptBuffer.updatePartial(transcript);
    }

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      currentTranscript: _transcriptBuffer.visible,
      isCapturingSpeech: true,
      clearError: true,
    );
    _armTranscriptIdleEndpointTimeout(_callGeneration);
  }

  void endpointUtterance() {
    if (!state.isCallActive) {
      return;
    }

    _cancelNoSpeechTimeout();
    _isAwaitingFollowUpSpeech = false;
    state = state.copyWith(
      phase: VoiceCallPhase.thinking,
      isCapturingSpeech: false,
      clearError: true,
    );
    _cancelListeningEndpointTimeout();
    _armThinkingTimeout(_callGeneration);
  }

  void startTranscribing() {
    if (!state.isCallActive) {
      return;
    }

    _cancelNoSpeechTimeout();
    _isAwaitingFollowUpSpeech = false;
    state = state.copyWith(
      phase: VoiceCallPhase.thinking,
      isCapturingSpeech: false,
      clearError: true,
    );
    _cancelListeningEndpointTimeout();
    _armThinkingTimeout(_callGeneration);
  }

  void startThinking({String? finalTranscript}) {
    if (!state.isCallActive) {
      return;
    }

    _cancelNoSpeechTimeout();
    _isAwaitingFollowUpSpeech = false;
    if (finalTranscript != null) {
      _transcriptBuffer.appendFinal(finalTranscript);
    }

    state = state.copyWith(
      phase: VoiceCallPhase.thinking,
      currentTranscript: _transcriptBuffer.visible,
      isCapturingSpeech: false,
      clearError: true,
    );
    _cancelListeningEndpointTimeout();
    _armThinkingTimeout(_callGeneration);
  }

  void interrupt({String? reason}) {
    if (!state.isCallActive) {
      return;
    }
    _callGeneration++;
    _cancelThinkingTimeout();
    _cancelListeningEndpointTimeout();
    _cancelNoSpeechTimeout();
    unawaited(_stopInterimTranscription());
    if (_isUsingNativeVoice) {
      unawaited(_nativeVoiceSessionService.interrupt());
      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        isCapturingSpeech: false,
        errorMessage: reason,
      );
      return;
    }
    unawaited(_captureService.cancel());
    unawaited(_streamingCaptureService.cancel());
    _stopBargeInMonitoring();
    final streamingSession = _activeStreamingSession;
    _activeStreamingSession = null;
    streamingSession?.interrupt();
    unawaited(_streamingPlaybackQueue.cancel());
    unawaited(streamingSession?.endSession());
    unawaited(_playbackService.stop());

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      errorMessage: reason,
    );
  }

  void resumeListening() {
    if (!state.isCallActive) {
      return;
    }

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      clearCurrentTranscript: true,
      clearError: true,
    );
    _cancelThinkingTimeout();
    _cancelListeningEndpointTimeout();
    _cancelNoSpeechTimeout();
    unawaited(_stopInterimTranscription());
    _clearVisibleTranscript();
    if (_isUsingNativeVoice) {
      unawaited(_nativeVoiceSessionService.interrupt());
      return;
    }
    _startListeningCycle(_callGeneration);
  }

  void reset() {
    _callGeneration++;
    _isAwaitingFollowUpSpeech = false;
    _cancelThinkingTimeout();
    _cancelListeningEndpointTimeout();
    _cancelNoSpeechTimeout();
    unawaited(_stopInterimTranscription());
    _stopNativeVoiceSession();
    unawaited(_captureService.cancel());
    unawaited(_streamingCaptureService.cancel());
    _stopBargeInMonitoring();
    final streamingSession = _activeStreamingSession;
    _activeStreamingSession = null;
    streamingSession?.interrupt();
    unawaited(_streamingPlaybackQueue.cancel());
    unawaited(streamingSession?.endSession());
    unawaited(_playbackService.stop());
    unawaited(_backgroundVoiceService.stop());
    unawaited(_audioSessionService.setActive(false));
    _clearVisibleTranscript();
    state = const VoiceCallState();
  }
}
