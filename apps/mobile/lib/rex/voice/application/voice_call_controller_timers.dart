// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

const _maxEmptyVoiceTurnRecoveries = 3;

extension VoiceCallControllerTimers on VoiceCallController {
  bool _isCurrentCall(int generation) => generation == _callGeneration;

  void _armThinkingTimeout(int generation) {
    _thinkingTimeoutTimer?.cancel();
    final timeout = ref.read(voiceCallThinkingTimeoutProvider);
    if (timeout <= Duration.zero) {
      return;
    }
    _thinkingTimeoutTimer = Timer(timeout, () {
      _recoverFromStuckThinking(generation);
    });
  }

  void _cancelThinkingTimeout() {
    _thinkingTimeoutTimer?.cancel();
    _thinkingTimeoutTimer = null;
  }

  bool _isNoAudioError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('did not catch') ||
        normalized.contains('no audio') ||
        normalized.contains('empty audio');
  }

  Future<void> _startInterimTranscription(int generation) async {
    if (!_isCurrentCall(generation) ||
        !state.isCallActive ||
        state.phase != VoiceCallPhase.listening) {
      return;
    }

    final service = _interimSpeechToTextService;
    try {
      final available = await service.initialize(onError: (_) {});
      if (!available ||
          !_isCurrentCall(generation) ||
          state.phase != VoiceCallPhase.listening) {
        return;
      }
      await service.startListening(
        onPartialTranscript: (transcript) {
          if (_isCurrentCall(generation) &&
              state.phase == VoiceCallPhase.listening) {
            updateTranscript(transcript);
          }
        },
        onFinalTranscript: (transcript) {
          if (_isCurrentCall(generation) &&
              state.phase == VoiceCallPhase.listening) {
            updateTranscript(transcript, isFinal: true);
          }
        },
        onError: (_) {},
      );
    } on Object {
      // Interim local transcription is only a UI aid. Deepgram remains the
      // source of truth after the recorded turn is uploaded.
    }
  }

  Future<void> _stopInterimTranscription() async {
    final service = _activeInterimSpeechToTextService;
    if (service == null) {
      return;
    }
    try {
      await service.cancel();
    } on Object {
      // Best effort cleanup only.
    }
  }

  void _recoverFromEmptyVoiceTurn(String message) {
    if (!state.isCallActive) {
      return;
    }
    _emptyVoiceTurnRecoveryCount++;
    if (_emptyVoiceTurnRecoveryCount > _maxEmptyVoiceTurnRecoveries) {
      failL10n((l10n) => l10n.voiceErrorStillDidNotHear);
      return;
    }
    if (_isAwaitingFollowUpSpeech) {
      final generation = ++_callGeneration;
      _cancelThinkingTimeout();
      _cancelNoSpeechTimeout();
      unawaited(_stopInterimTranscription());
      unawaited(_captureService.cancel());
      unawaited(_streamingCaptureService.cancel());
      _stopBargeInMonitoring();
      final streamingSession = _activeStreamingSession;
      streamingSession?.interrupt();
      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        isCapturingSpeech: false,
        clearCurrentTranscript: true,
        clearError: true,
      );
      _clearVisibleTranscript();
      _removeActiveVoiceUserMessage();
      _startListeningCycle(generation);
      return;
    }
    final generation = ++_callGeneration;
    _cancelThinkingTimeout();
    _cancelNoSpeechTimeout();
    unawaited(_stopInterimTranscription());
    unawaited(_captureService.cancel());
    unawaited(_streamingCaptureService.cancel());
    _stopBargeInMonitoring();
    final streamingSession = _activeStreamingSession;
    streamingSession?.interrupt();

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      clearCurrentTranscript: true,
      clearError: true,
    );
    _clearVisibleTranscript();
    _removeActiveVoiceUserMessage();
    _startListeningCycle(generation);
  }

  void _markListeningReady() {
    if (!state.isCallActive || state.phase != VoiceCallPhase.listening) {
      return;
    }

    state = state.copyWith(
      listeningReadySignal: state.listeningReadySignal + 1,
    );
  }

  void _armNoSpeechTimeout(int generation) {
    _noSpeechTimeoutTimer?.cancel();
    final timeout = ref.read(voiceCallNoSpeechTimeoutProvider);
    if (timeout <= Duration.zero) {
      return;
    }
    _noSpeechTimeoutTimer = Timer(timeout, () {
      if (!_isCurrentCall(generation) ||
          !_isAppInForeground ||
          !state.isCallActive ||
          state.phase != VoiceCallPhase.listening ||
          state.isMuted ||
          state.isCapturingSpeech ||
          state.currentTranscript.trim().isNotEmpty) {
        return;
      }
      _recoverFromEmptyVoiceTurn(
        voiceL10n.voiceFailureDidNotCatch,
      );
    });
  }

  void _cancelNoSpeechTimeout() {
    _noSpeechTimeoutTimer?.cancel();
    _noSpeechTimeoutTimer = null;
  }

  void _recoverFromStreamingDisconnect() {
    if (!state.isCallActive) {
      return;
    }

    final generation = ++_callGeneration;
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
    unawaited(_playbackService.stop());
    unawaited(_audioSessionService.configureForVoiceTurn());
    unawaited(_backgroundVoiceService.start());

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      clearCurrentTranscript: true,
      errorMessage: voiceL10n.voiceErrorAssistantStreamDisconnected,
    );
    _clearVisibleTranscript();
    _removeActiveVoiceUserMessage();
    _startListeningCycle(generation);
  }

  void _recoverFromStuckThinking(int generation) {
    if (!_isCurrentCall(generation) ||
        !state.isCallActive ||
        state.phase != VoiceCallPhase.thinking) {
      return;
    }
    // Never interrupt an in-flight or failed confirm — Truth Rule / A25.
    // Resume listening only after the confirm resolves or the user dismisses.
    if (_pausedForSaveConfirmation ||
        _blockListenForSaveConfirmation ||
        _hasPendingSaveConfirmation()) {
      _cancelThinkingTimeout();
      return;
    }

    final nextGeneration = ++_callGeneration;
    _cancelThinkingTimeout();
    if (_isUsingNativeVoice) {
      unawaited(_nativeVoiceSessionService.interrupt());
      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        isCapturingSpeech: false,
        errorMessage: voiceL10n.voiceErrorStuckThinkingNative,
      );
      return;
    }
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
    unawaited(_audioSessionService.configureForVoiceTurn());
    unawaited(_backgroundVoiceService.start());

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      errorMessage: voiceL10n.voiceErrorStuckThinking,
    );
    _startListeningCycle(nextGeneration);
  }

  void _startBargeInMonitoring(int generation) {
    if (_isBargeInMonitoring ||
        !ref.read(voiceCallBargeInEnabledProvider) ||
        !_isCurrentCall(generation) ||
        state.phase != VoiceCallPhase.speaking ||
        state.isMuted) {
      return;
    }

    _isBargeInMonitoring = true;
    unawaited(
      _bargeInDetectionService
          .start(
            config: ref.read(voiceCaptureConfigProvider),
            onBargeIn: (audioChunks) {
              if (_isCurrentCall(generation) &&
                  state.phase == VoiceCallPhase.speaking &&
                  !state.isMuted) {
                debugPrint(
                  'rex_voice_barge_in detected chunks=${audioChunks.length}',
                );
                interruptAndListen(initialAudioChunks: audioChunks);
              }
            },
          )
          .catchError((Object _) {
            _isBargeInMonitoring = false;
          }),
    );
  }

  void _stopBargeInMonitoring() {
    if (!_isBargeInMonitoring && _activeBargeInDetectionService == null) {
      return;
    }
    _isBargeInMonitoring = false;
    unawaited(_bargeInDetectionService.stop());
  }

  void _handleTurnInProgressEvent() {
    if (!state.isCallActive) {
      return;
    }
    _cancelNoSpeechTimeout();
    unawaited(_stopInterimTranscription());
    if (state.phase == VoiceCallPhase.thinking ||
        state.phase == VoiceCallPhase.speaking) {
      state = state.copyWith(clearError: true);
      return;
    }
    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      errorMessage: voiceL10n.voiceErrorPreviousResponseInProgress,
    );
  }

  void _clearVisibleTranscript() {
    _transcriptBuffer.clear();
  }
}
