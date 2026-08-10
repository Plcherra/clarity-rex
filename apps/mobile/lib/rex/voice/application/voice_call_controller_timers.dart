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
    // Known speech must never be wiped into the music/mic soft-recover loop.
    // Typed voice already uses REST chat+TTS; use that when streaming failed
    // after the client already has the transcript (common when WS never lands
    // on the API but local/interim STT still shows words).
    if (_completeStreamingTurnViaChatFallback()) {
      debugPrint('rex_voice_stream recover_diverted_to_chat_fallback');
      return;
    }
    _emptyVoiceTurnRecoveryCount++;
    if (_emptyVoiceTurnRecoveryCount > _maxEmptyVoiceTurnRecoveries) {
      failL10n((l10n) => l10n.voiceErrorStillDidNotHear);
      return;
    }
    final generation = ++_callGeneration;
    _cancelThinkingTimeout();
    _cancelNoSpeechTimeout();
    _cancelSpeechFinalGrace();
    _cancelListeningEndpointTimeout();
    unawaited(_stopInterimTranscription());
    unawaited(_captureService.cancel());
    unawaited(_streamingCaptureService.cancel());
    _stopBargeInMonitoring();
    _suppressStaleSpeechFinal = false;
    _resetPendingUtteranceTranscript();
    // Soft listen retry: do not interrupt live STT. interrupt() wipes Deepgram
    // audio and drops late speech_final — the stuck-on-listening loop.
    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      clearCurrentTranscript: true,
      clearError: true,
    );
    _clearVisibleTranscript();
    // Abandon the local user bubble even if finalize already flipped interim
    // off — otherwise chat keeps the text while the bottom status resets.
    _removeActiveVoiceUserMessage(evenIfFinalized: true);
    _startListeningCycle(generation);
  }

  void _armSpeechFinalGraceAfterCapture(int generation, int listenEpoch) {
    _speechFinalGraceTimer?.cancel();
    // Match local VAD post-speech silence so walking pauses and slow Deepgram
    // finals can still finalize before we soft-recover listen.
    _speechFinalGraceTimer = Timer(const Duration(milliseconds: 8500), () {
      if (!_isCurrentCall(generation) ||
          listenEpoch != _streamingListenEpoch ||
          !state.isCallActive ||
          state.phase != VoiceCallPhase.listening ||
          state.isMuted) {
        return;
      }
      if (_holdUtteranceEndForLifecycle) {
        _restartListenAfterLifecycleHold = true;
        return;
      }
      if (_streamingTurnFinalizedSequence == _streamingTurnSequence) {
        return;
      }
      final transcript = _transcriptBuffer.visible.trim();
      if (transcript.isNotEmpty) {
        _endTurnFromLocalEndpoint(
          generation,
          reason: VoiceTurnFinalizeReason.speechFinalAfterVad,
          preferredTranscript: transcript,
        );
        return;
      }
      _recoverFromEmptyVoiceTurn(voiceL10n.voiceFailureDidNotCatch);
    });
  }

  void _cancelSpeechFinalGrace() {
    _speechFinalGraceTimer?.cancel();
    _speechFinalGraceTimer = null;
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

  /// Re-arm when STT transcript updates. After [voiceCallTranscriptIdleTimeoutProvider]
  /// of stability with a non-empty transcript, finalize the turn (utterance.end).
  /// This is Deepgram/STT endpointing parity — not an artificial race timeout.
  void _armTranscriptIdleEndpointTimeout(int generation) {
    if (_activeStreamingSession == null ||
        _transcriptBuffer.visible.trim().isEmpty ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }
    _armListeningEndpointTimeout(
      generation,
      ref.read(voiceCallTranscriptIdleTimeoutProvider),
    );
  }

  void _armListeningEndpointTimeout(int generation, Duration timeout) {
    _listeningEndpointTimer?.cancel();
    if (timeout <= Duration.zero) {
      return;
    }
    _listeningEndpointTimer = Timer(timeout, () {
      // Mic still in active speech (breaths / STT lag) — do not cut the turn
      // on transcript-idle alone. Wait for VAD speech_end or a quiet window.
      if (state.isCapturingSpeech) {
        _armListeningEndpointTimeout(generation, timeout);
        return;
      }
      _forceEndStreamingUtterance(generation);
    });
  }

  void _cancelListeningEndpointTimeout() {
    _listeningEndpointTimer?.cancel();
    _listeningEndpointTimer = null;
  }

  void _forceEndStreamingUtterance(int generation) {
    _cancelListeningEndpointTimeout();
    if (!_isCurrentCall(generation) ||
        !state.isCallActive ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }
    if (_holdUtteranceEndForLifecycle) {
      _restartListenAfterLifecycleHold = true;
      return;
    }
    if (_streamingTurnFinalizedSequence == _streamingTurnSequence) {
      return;
    }
    if (state.isCapturingSpeech) {
      return;
    }
    // STT idle must never masquerade as VAD — leave capture running.
    if (!_vadSilenceReachedForTurn) {
      _voiceTrace.record(
        event: 'finalize.rejected',
        reason: 'idle_without_vad',
        turnId: '$_streamingTurnSequence',
        fromPhase: state.phase.name,
        toPhase: state.phase.name,
      );
      debugPrint('rex_voice_authority reject_idle_without_vad');
      return;
    }
    _endTurnFromLocalEndpoint(
      generation,
      reason: VoiceTurnFinalizeReason.transcriptIdleAfterVad,
    );
    unawaited(_streamingCaptureService.cancel());
    unawaited(_stopInterimTranscription());
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
