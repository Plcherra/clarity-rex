// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerStreamingCapture on VoiceCallController {
  Future<void> _streamNextUtteranceConnected(
    int generation, {
    List<Uint8List> initialAudioChunks = const [],
  }) async {
    late final StreamingVoiceSession session;
    final existingSession = _activeStreamingSession;
    if (existingSession == null) {
      try {
        final connectedSession = await ref
            .read(streamingVoiceApiProvider)
            .connect(
              conversationId: state.conversationId,
              client: ref.read(streamingVoiceClientProvider),
            );
        session = connectedSession;
        _activeStreamingSession = connectedSession;
        _activeStreamingEventsTask = _handleStreamingEvents(connectedSession);
        unawaited(_activeStreamingEventsTask);
      } on StreamingVoiceApiException catch (error) {
        if (_isCurrentCall(generation)) {
          await _fallbackToCloudVoiceCapture(generation, error.message);
        }
        return;
      } on Object {
        if (_isCurrentCall(generation)) {
          await _fallbackToCloudVoiceCapture(
            generation,
            voiceL10n.voiceErrorOpenAssistantStreamFailed,
          );
        }
        return;
      }
    } else {
      session = existingSession;
    }

    final turnSequence = ++_streamingTurnSequence;
    _streamingUtteranceEndSent = false;
    _resetPrefetchedFinancialContext();
    for (final chunk in initialAudioChunks) {
      session.sendAudioChunk(chunk);
    }
    if (initialAudioChunks.isNotEmpty) {
      startCapturingSpeech();
    }

    final bool capturedAudio;
    try {
      capturedAudio = await _streamingCaptureService.streamUtterance(
        config: ref.read(voiceCaptureConfigProvider),
        onReady: () {
          if (_isCurrentCall(generation) &&
              state.phase == VoiceCallPhase.listening) {
            _markListeningReady();
            _armNoSpeechTimeout(generation);
          }
        },
        onSpeechStart: () {
          if (_isCurrentCall(generation) &&
              state.phase == VoiceCallPhase.listening) {
            startCapturingSpeech();
          }
        },
        onSpeechEnded: () {
          if (_isCurrentCall(generation) &&
              state.phase == VoiceCallPhase.listening) {
            endpointUtterance();
            _sendStreamingUtteranceEndIfNeeded(session, turnSequence);
          }
        },
        onAudioChunk: (chunk) async {
          if (_isCurrentCall(generation)) {
            session.sendAudioChunk(chunk);
          }
        },
      );
    } on Object {
      if (_isCurrentCall(generation)) {
        if (_isAppInForeground) {
          failL10n((l10n) => l10n.voiceErrorStreamVoiceAudioFailed);
        } else {
          _deferBackgroundStreamingRestart(session);
        }
      }
      if (!identical(_activeStreamingSession, session)) {
        unawaited(session.endSession());
      }
      return;
    }

    if (!_isCurrentCall(generation) || !state.isCallActive) {
      if (!identical(_activeStreamingSession, session)) {
        unawaited(session.endSession());
      }
      return;
    }
    if (!capturedAudio) {
      if (state.phase == VoiceCallPhase.thinking ||
          state.phase == VoiceCallPhase.speaking) {
        return;
      }
      _recoverFromEmptyVoiceTurn('I did not catch that. I am listening again.');
      return;
    }

    endpointUtterance();
    _sendStreamingUtteranceEndIfNeeded(session, turnSequence);
  }

  Future<void> _streamNextUtteranceWeb(
    int generation, {
    List<Uint8List> initialAudioChunks = const [],
  }) async {
    StreamingVoiceSession? session;
    final pendingChunks = <Uint8List>[...initialAudioChunks];
    final turnSequence = ++_streamingTurnSequence;
    _streamingUtteranceEndSent = false;
    _resetPrefetchedFinancialContext();

    if (initialAudioChunks.isNotEmpty) {
      startCapturingSpeech();
    }

    void flushPendingChunks(StreamingVoiceSession activeSession) {
      if (pendingChunks.isEmpty) {
        return;
      }
      for (final chunk in pendingChunks) {
        activeSession.sendAudioChunk(chunk);
      }
      pendingChunks.clear();
    }

    void notifyListeningReady() {
      if (!_isCurrentCall(generation) ||
          state.phase != VoiceCallPhase.listening) {
        return;
      }
      final activeSession = session ?? _activeStreamingSession;
      if (activeSession == null) {
        return;
      }
      _markListeningReady();
      _armNoSpeechTimeout(generation);
      if (state.isCapturingSpeech) {
        _armSpeechStartedEndpointTimeout(generation);
      }
    }

    // Open the mic before any network I/O so browser user activation is still
    // valid when the user just tapped start voice on web.
    final captureFuture = _streamingCaptureService.streamUtterance(
      config: ref.read(voiceCaptureConfigProvider),
      onReady: notifyListeningReady,
      onSpeechStart: () {
        if (_isCurrentCall(generation) &&
            state.phase == VoiceCallPhase.listening) {
          startCapturingSpeech();
          _armSpeechStartedEndpointTimeout(generation);
        }
      },
      onSpeechEnded: () {
        if (_isCurrentCall(generation) &&
            state.phase == VoiceCallPhase.listening) {
          endpointUtterance();
          final activeSession = session ?? _activeStreamingSession;
          if (activeSession != null) {
            _sendStreamingUtteranceEndIfNeeded(activeSession, turnSequence);
          }
        }
      },
      onAudioChunk: (chunk) async {
        if (!_isCurrentCall(generation)) {
          return;
        }
        final activeSession = session ?? _activeStreamingSession;
        if (activeSession != null) {
          activeSession.sendAudioChunk(chunk);
        } else {
          pendingChunks.add(chunk);
        }
      },
    );

    try {
      final connectedSession = await ref
          .read(streamingVoiceApiProvider)
          .connect(
            conversationId: state.conversationId,
            client: ref.read(streamingVoiceClientProvider),
          );
      if (!_isCurrentCall(generation) ||
          state.phase != VoiceCallPhase.listening ||
          state.isMuted) {
        await _streamingCaptureService.cancel();
        unawaited(connectedSession.endSession());
        return;
      }
      session = connectedSession;
      _activeStreamingSession = connectedSession;
      _activeStreamingEventsTask = _handleStreamingEvents(connectedSession);
      unawaited(_activeStreamingEventsTask);
      flushPendingChunks(connectedSession);
      notifyListeningReady();
    } on StreamingVoiceApiException catch (error) {
      await _streamingCaptureService.cancel();
      if (_isCurrentCall(generation)) {
        await _fallbackToCloudVoiceCapture(generation, error.message);
      }
      return;
    } on Object {
      await _streamingCaptureService.cancel();
      if (_isCurrentCall(generation)) {
        await _fallbackToCloudVoiceCapture(
          generation,
          voiceL10n.voiceErrorOpenAssistantStreamFailed,
        );
      }
      return;
    }

    final bool capturedAudio;
    try {
      capturedAudio = await captureFuture;
    } on Object {
      if (_isCurrentCall(generation)) {
        failL10n((l10n) => l10n.voiceErrorStreamVoiceAudioFailed);
      }
      if (session != null && !identical(_activeStreamingSession, session)) {
        unawaited(session.endSession());
      }
      return;
    }

    if (!_isCurrentCall(generation) || !state.isCallActive) {
      if (session != null && !identical(_activeStreamingSession, session)) {
        unawaited(session.endSession());
      }
      return;
    }
    if (!capturedAudio) {
      if (state.phase == VoiceCallPhase.thinking ||
          state.phase == VoiceCallPhase.speaking) {
        return;
      }
      _recoverFromEmptyVoiceTurn('I did not catch that. I am listening again.');
      return;
    }

    endpointUtterance();
    final activeSession = session ?? _activeStreamingSession;
    if (activeSession != null) {
      _sendStreamingUtteranceEndIfNeeded(activeSession, turnSequence);
    }
  }

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
        _recoverFromEmptyVoiceTurn(
          'I did not catch that. I am listening again.',
        );
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
      final response = await ref
          .read(cloudVoiceApiProvider)
          .sendVoiceTurn(
            audio: recording.file,
            inputMimeType: recording.inputMimeType,
            conversationId: state.conversationId,
            financialContext: await _financialContext(state.currentTranscript),
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
          _recoverFromEmptyVoiceTurn(
            'I did not catch that. I am listening again.',
          );
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
