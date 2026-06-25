// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerCommands on VoiceCallController {
  void startCapturingSpeech({String transcript = ''}) {
    if (!state.isCallActive) {
      return;
    }

    _isAwaitingFollowUpSpeech = false;
    if (transcript.trim().isNotEmpty) {
      _emptyVoiceTurnRecoveryCount = 0;
    }
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
      if (finalTranscript.trim().isNotEmpty) {
        _emptyVoiceTurnRecoveryCount = 0;
      }
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

  void beginTypedTextTurn(String text) {
    if (!state.isCallActive) {
      return;
    }

    final transcript = text.trim();
    final generation = ++_callGeneration;
    _cancelThinkingTimeout();
    _cancelListeningEndpointTimeout();
    _cancelNoSpeechTimeout();
    unawaited(_stopInterimTranscription());
    if (_isUsingNativeVoice) {
      unawaited(_nativeVoiceSessionService.interrupt());
    } else {
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
    }
    _clearVisibleTranscript();
    state = state.copyWith(
      phase: VoiceCallPhase.thinking,
      currentTranscript: transcript,
      isCapturingSpeech: false,
      clearError: true,
    );
    _armThinkingTimeout(generation);
  }

  Future<void> speakTypedAssistantResponse(String responseText) async {
    final text = responseText.trim();
    if (!state.isCallActive || text.isEmpty) {
      return;
    }

    final generation = _callGeneration;
    _cancelThinkingTimeout();
    state = state.copyWith(lastAssistantResponse: text, clearError: true);

    if (state.isMuted) {
      resumeListening();
      return;
    }

    try {
      final response = await ref.read(cloudVoiceApiProvider).synthesize(text);
      if (!_isCurrentCall(generation) || !state.isCallActive) {
        return;
      }

      startSpeaking(text);
      _startBargeInMonitoring(generation);
      await _audioSessionService.preferLoudSpeaker();
      await _playbackService.playBase64Audio(
        response.audioBase64,
        contentType: response.audioContentType,
        onComplete: () {
          if (_isCurrentCall(generation)) {
            _stopBargeInMonitoring();
            completeSpeaking();
          }
        },
        onError: (message) {
          if (_isCurrentCall(generation)) {
            _stopBargeInMonitoring();
            fail(message);
          }
        },
      );
    } on CloudVoiceApiException catch (error) {
      if (_isCurrentCall(generation)) {
        fail(error.message);
      }
    } on Object {
      if (_isCurrentCall(generation)) {
        fail('Could not play Rex voice for this reply.');
      }
    }
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
    streamingSession?.interrupt();
    unawaited(_streamingPlaybackQueue.cancel());
    unawaited(_playbackService.stop());

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      errorMessage: reason,
    );
    _startListeningCycle(_callGeneration);
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
    _emptyVoiceTurnRecoveryCount = 0;
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
    _activeStreamingEventsTask = null;
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
