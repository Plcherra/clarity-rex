// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerStreamingTurn on VoiceCallController {
  void _startListeningCycle(
    int generation, {
    List<Uint8List> initialAudioChunks = const [],
  }) {
    if (_isUsingNativeVoice) {
      return;
    }
    if (state.phase == VoiceCallPhase.listening) {
      _cancelThinkingTimeout();
    }
    _cancelListeningEndpointTimeout();
    if (!_isCurrentCall(generation) ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }

    if (ref.read(streamingVoiceEnabledProvider)) {
      unawaited(
        _streamNextUtterance(
          generation,
          initialAudioChunks: initialAudioChunks,
        ),
      );
    } else {
      unawaited(_captureNextUtterance(generation));
    }
  }

  Future<void> _streamNextUtterance(
    int generation, {
    List<Uint8List> initialAudioChunks = const [],
  }) async {
    if (!_isCurrentCall(generation) ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }

    if (kIsWeb && _activeStreamingSession == null) {
      await _streamNextUtteranceWeb(
        generation,
        initialAudioChunks: initialAudioChunks,
      );
      return;
    }

    await _streamNextUtteranceConnected(
      generation,
      initialAudioChunks: initialAudioChunks,
    );
  }

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
      startThinking();
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
      ref
          .read(chatProvider.notifier)
          .applyBackendMessages(
            conversationId: response.conversationId,
            messages: response.messages,
            fallbackAssistantResponse: response.responseText,
            memoryChanges: response.memoryChanges,
          );

      _clearVisibleTranscript();
      startThinking(finalTranscript: response.transcript);
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

  Future<void> _handleStreamingEvents(StreamingVoiceSession session) async {
    var assistantText = '';
    var responseAudioStarted = false;
    DateTime? assistantStartedAt;
    DateTime? firstAudioChunkAt;
    DateTime? lastAudioChunkStartedAt;
    var streamEndedCleanly = false;
    bool isActiveSession() =>
        identical(_activeStreamingSession, session) && state.isCallActive;

    void beginStreamingAudioIfNeeded() {
      if (responseAudioStarted) {
        return;
      }
      responseAudioStarted = true;
      unawaited(_audioSessionService.preferLoudSpeaker());
      _streamingPlaybackQueue.beginResponse();
    }

    StreamingAudioPlaybackCallbacks playbackCallbacks() {
      return StreamingAudioPlaybackCallbacks(
        onChunkStarted: (chunk) {
          if (isActiveSession()) {
            final now = DateTime.now();
            firstAudioChunkAt ??= now;
            final previousChunkAt = lastAudioChunkStartedAt;
            lastAudioChunkStartedAt = now;
            debugPrint(
              'rex_voice_playback chunk_started '
              'first_audio_ms=${_elapsedSince(assistantStartedAt, now)} '
              'chunk_gap_ms=${_elapsedSince(previousChunkAt, now)} '
              'text_chars=${chunk.text.length}',
            );
            startSpeaking(assistantText);
            _startBargeInMonitoring(_callGeneration);
          }
        },
        onQueueDrained: () {
          debugPrint(
            'rex_voice_playback queue_drained '
            'speaking_ms=${_elapsedSince(firstAudioChunkAt, DateTime.now())}',
          );
          _stopBargeInMonitoring();
        },
        onError: (message) {
          _stopBargeInMonitoring();
          if (isActiveSession()) {
            failVoiceApi(CloudVoiceApiException(message));
          }
        },
      );
    }

    try {
      await for (final event in session.events) {
        if (!isActiveSession()) {
          return;
        }

        switch (event.name) {
          case 'session.started':
            break;
          case 'transcript.partial':
            if (state.phase == VoiceCallPhase.listening) {
              updateTranscript(event.transcript ?? state.currentTranscript);
            }
          case 'transcript.final':
            if (event.speechFinal) {
              assistantText = '';
              responseAudioStarted = false;
              startThinking(finalTranscript: event.transcript);
              _sendStreamingUtteranceEndIfNeeded(
                session,
                _streamingTurnSequence,
              );
              unawaited(_activeStreamingCaptureService?.cancel());
            } else if (state.phase == VoiceCallPhase.thinking) {
              startThinking(finalTranscript: event.transcript);
            } else if (state.phase == VoiceCallPhase.listening) {
              updateTranscript(
                event.transcript ?? state.currentTranscript,
                isFinal: true,
              );
            }
          case 'conversation.updated':
            state = state.copyWith(
              conversationId: event.conversationId,
              clearError: true,
            );
          case 'assistant.started':
            assistantStartedAt = DateTime.now();
            unawaited(_activeStreamingCaptureService?.cancel());
            if (state.phase != VoiceCallPhase.thinking) {
              startThinking(finalTranscript: state.currentTranscript);
            }
            _armThinkingTimeout(_callGeneration);
            beginStreamingAudioIfNeeded();
          case 'assistant.token':
            assistantText += event.token ?? '';
            _armThinkingTimeout(_callGeneration);
            state = state.copyWith(lastAssistantResponse: assistantText);
          case 'assistant.audio_chunk':
            final audioBase64 = event.audioBase64;
            if (audioBase64 == null || audioBase64.isEmpty) {
              break;
            }
            beginStreamingAudioIfNeeded();
            _streamingPlaybackQueue.enqueue(
              StreamingAudioChunk(
                audioBase64: audioBase64,
                contentType: event.audioContentType,
                text: event.data['text'] as String? ?? '',
              ),
              callbacks: playbackCallbacks(),
            );
          case 'messages.updated':
            final rawMessages = event.data['messages'];
            if (event.conversationId != null && rawMessages is List) {
              final messages = rawMessages
                  .whereType<Map<String, dynamic>>()
                  .map(ChatApiMessage.fromJson)
                  .toList(growable: false);
              ref
                  .read(chatProvider.notifier)
                  .applyBackendMessages(
                    conversationId: event.conversationId!,
                    messages: messages,
                    fallbackAssistantResponse: assistantText,
                    memoryChanges: event.memoryChanges,
                  );
            }
          case 'assistant.done':
            _cancelThinkingTimeout();
            final completedText = (event.responseText ?? assistantText).trim();
            beginStreamingAudioIfNeeded();
            debugPrint(
              'rex_voice_playback assistant_done timings=${event.data['timings']}',
            );
            if (event.conversationId != null) {
              state = state.copyWith(
                conversationId: event.conversationId,
                lastAssistantResponse: completedText,
                clearError: true,
              );
            }
            _streamingPlaybackQueue.finishResponse(
              callbacks: playbackCallbacks(),
            );
            if (kIsWeb && !_isAppInForeground) {
              await _streamingPlaybackQueue.cancel();
            } else {
              try {
                await _streamingPlaybackQueue.waitUntilIdle().timeout(
                  const Duration(seconds: 30),
                );
              } on TimeoutException {
                await _streamingPlaybackQueue.cancel();
              }
            }
            _stopBargeInMonitoring();
            if (isActiveSession()) {
              if (firstAudioChunkAt == null &&
                  completedText.isNotEmpty &&
                  !state.isMuted) {
                final fallbackStarted = await _playSynthesizedStreamingFallback(
                  completedText,
                  _callGeneration,
                );
                if (fallbackStarted) {
                  break;
                }
              }
              if (state.phase == VoiceCallPhase.speaking) {
                completeSpeaking();
                debugPrint('rex_voice_playback listening_resumed');
              } else if (state.phase != VoiceCallPhase.listening &&
                  !state.isMuted) {
                resumeListening();
                debugPrint('rex_voice_playback listening_resumed');
              }
            }
          case 'session.ended':
            streamEndedCleanly = true;
            return;
          case 'session.interrupted':
            break;
          case 'error':
            if (event.errorCode == 'turn_in_progress') {
              _handleTurnInProgressEvent();
              break;
            }
            if (event.errorCode == 'empty_audio' ||
                _isNoAudioError(event.detail ?? '')) {
              debugPrint('rex_voice_stream empty_audio_recovered');
              _recoverFromEmptyVoiceTurn(
                'I did not catch that. I am listening again.',
              );
              break;
            }
            final detail = event.detail?.trim();
            if (detail == null || detail.isEmpty) {
              failL10n((l10n) => l10n.voiceErrorAssistantStreamFailed);
            } else {
              failVoiceApi(StreamingVoiceApiException(detail));
            }
            return;
        }
      }
    } on StreamingVoiceApiException catch (error) {
      if (isActiveSession()) {
        failVoiceApi(error);
      }
    } on Object {
      if (isActiveSession()) {
        failL10n((l10n) => l10n.voiceErrorAssistantStreamFailed);
      }
    } finally {
      if (identical(_activeStreamingSession, session)) {
        debugPrint('rex_voice_stream listener_detached');
        _activeStreamingSession = null;
        _activeStreamingEventsTask = null;
        if (!streamEndedCleanly && state.isCallActive) {
          failL10n((l10n) => l10n.voiceErrorAssistantStreamDisconnected);
        }
      }
    }
  }

  Future<bool> _playSynthesizedStreamingFallback(
    String responseText,
    int generation,
  ) async {
    if (!_isCurrentCall(generation) || !state.isCallActive) {
      return false;
    }
    debugPrint(
      'rex_voice_playback fallback_synthesize text_chars=${responseText.length}',
    );

    try {
      final response = await ref
          .read(cloudVoiceApiProvider)
          .synthesize(responseText);
      if (!_isCurrentCall(generation) || !state.isCallActive) {
        return true;
      }
      if (response.audioBase64.isEmpty) {
        failL10n((l10n) => l10n.voiceErrorPlayRexVoiceFailed);
        return true;
      }

      startSpeaking(responseText);
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
      return true;
    } on CloudVoiceApiException catch (error) {
      if (_isCurrentCall(generation)) {
        failVoiceApi(error);
      }
      return true;
    } on Object {
      if (_isCurrentCall(generation)) {
        failL10n((l10n) => l10n.voiceErrorPlayRexVoiceFailed);
      }
      return true;
    }
  }

  void _sendStreamingUtteranceEndIfNeeded(
    StreamingVoiceSession session,
    int turnSequence,
  ) {
    if (_streamingUtteranceEndSent) {
      return;
    }
    _streamingUtteranceEndSent = true;
    unawaited(
      _financialContext(state.currentTranscript).then((financialContext) {
        if (turnSequence != _streamingTurnSequence ||
            !identical(_activeStreamingSession, session) ||
            !state.isCallActive) {
          return;
        }
        session.endUtterance(
          financialContext: financialContext,
          writeConfirmation: ref
              .read(chatProvider.notifier)
              .writeConfirmationForAffirmation(state.currentTranscript),
        );
      }),
    );
  }

  Future<Map<String, dynamic>?> _financialContext([String? transcript]) async {
    if (transcript == null ||
        !shouldAttachAssistantFinancialContext(transcript)) {
      return null;
    }
    final service = ref.read(assistantFinancialContextServiceProvider);
    if (service == null) {
      return AssistantFinancialContextService.unavailableSummary(
        source: 'mobile_financial_context_service',
        message:
            'Financial context is not available in this voice session. Tell the user the financial data cannot be loaded right now.',
      );
    }
    try {
      return await service.buildSummary();
    } on Object catch (error) {
      return AssistantFinancialContextService.degradedSummary(
        source: 'mobile_financial_context_service',
        error: error,
      );
    }
  }

  int? _elapsedSince(DateTime? startedAt, DateTime now) {
    if (startedAt == null) {
      return null;
    }
    return now.difference(startedAt).inMilliseconds;
  }
}
