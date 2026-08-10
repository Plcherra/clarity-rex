// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerCloudFallback on VoiceCallController {
  Future<void> _fallbackToCloudVoiceCapture(
    int generation,
    String streamError,
  ) async {
    if (!_isCurrentCall(generation) ||
        !state.isCallActive ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }
    if (!ref.read(cloudVoiceEnabledProvider)) {
      failVoiceApi(StreamingVoiceApiException(streamError));
      return;
    }
    await _captureNextUtterance(generation);
  }

  void _deferBackgroundStreamingRestart(StreamingVoiceSession session) {
    unawaited(_streamingCaptureService.cancel());
    _cancelThinkingTimeout();
    if (kIsWeb) {
      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        isCapturingSpeech: false,
        clearError: true,
      );
      return;
    }
    if (identical(_activeStreamingSession, session)) {
      _activeStreamingSession = null;
      _activeStreamingEventsTask = null;
    }
    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      errorMessage: voiceL10n.voiceErrorBackgroundMicRestart,
    );
  }

  Future<void> _captureNextUtterance(int generation) async {
    if (!_isCurrentCall(generation) ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }

    final turnSequence = ++_streamingTurnSequence;
    _streamingUtteranceEndSent = false;
    _beginVoiceTurn(turnSequence);

    final RecordedVoiceAudio? recording;
    try {
      recording = await _captureService.captureUtterance(
        config: ref.read(voiceCaptureConfigProvider),
        onReady: () {
          if (_isCurrentCall(generation) &&
              state.phase == VoiceCallPhase.listening) {
            _markListeningReady();
            _armNoSpeechTimeout(generation);
            unawaited(_startInterimTranscription(generation));
          }
        },
        onSpeechStart: () {
          if (_isCurrentCall(generation) &&
              state.phase == VoiceCallPhase.listening) {
            startCapturingSpeech();
          }
        },
      );
    } on Object {
      unawaited(_stopInterimTranscription());
      if (_isCurrentCall(generation)) {
        failL10n((l10n) => l10n.voiceErrorCaptureVoiceAudioFailed);
      }
      return;
    }
    if (!_isCurrentCall(generation) || !state.isCallActive) {
      return;
    }
    if (recording == null) {
      if (state.phase == VoiceCallPhase.listening) {
        _recoverFromEmptyVoiceTurn(voiceL10n.voiceFailureDidNotCatch);
      }
      return;
    }

    endpointUtterance();
    unawaited(_stopInterimTranscription());
    await _sendCapturedUtterance(recording, generation);
  }

  Future<void> _sendCapturedUtterance(
    RecordedVoiceAudio recording,
    int generation,
  ) async {
    if (!_isCurrentCall(generation)) {
      return;
    }

    try {
      final localTranscript = state.currentTranscript;
      final writeConfirmation = ref
          .read(chatProvider.notifier)
          .writeConfirmationForAffirmation(localTranscript);
      final response = await ref
          .read(cloudVoiceApiProvider)
          .sendVoiceTurn(
            audio: recording.file,
            inputMimeType: recording.inputMimeType,
            conversationId: state.conversationId,
            financialContext: await _financialContext(localTranscript),
            writeConfirmation: writeConfirmation,
          );
      if (!_isCurrentCall(generation)) {
        return;
      }

      state = state.copyWith(
        conversationId: response.conversationId,
        clearError: true,
      );
      final chatNotifier = ref.read(chatProvider.notifier);
      chatNotifier.applyBackendMessages(
        conversationId: response.conversationId,
        messages: response.messages,
        fallbackAssistantResponse: response.responseText,
        memoryChanges: response.memoryChanges,
      );

      _clearVisibleTranscript();
      final transcript = response.transcript.trim();
      if (transcript.isNotEmpty &&
          !chatNotifier.hasUserMessageWithContent(transcript)) {
        chatNotifier.finalizeVoiceUserMessage(
          localId: _ensureActiveVoiceMessageLocalId(),
          content: transcript,
        );
      }
      startSpeaking(response.responseText);
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
            failVoiceApi(CloudVoiceApiException(message));
          }
        },
      );
    } on CloudVoiceApiException catch (error) {
      if (_isCurrentCall(generation)) {
        if (_isNoAudioError(error.message)) {
          _recoverFromEmptyVoiceTurn(voiceL10n.voiceFailureDidNotCatch);
          return;
        }
        failVoiceApi(error);
      }
    } on Object {
      if (_isCurrentCall(generation)) {
        failL10n((l10n) => l10n.voiceErrorActiveCallFailed);
      }
    }
  }
}
