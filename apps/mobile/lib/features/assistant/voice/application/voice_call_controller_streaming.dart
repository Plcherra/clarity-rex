// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerStreamingTurn on VoiceCallController {
  void _startListeningCycle(int generation) {
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
      unawaited(_streamNextUtterance(generation));
    } else {
      unawaited(_captureNextUtterance(generation));
    }
  }

  Future<void> _streamNextUtterance(int generation) async {
    if (!_isCurrentCall(generation) ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }

    final StreamingVoiceSession session;
    try {
      final financialContext = await _financialContext();
      session = await ref
          .read(streamingVoiceApiProvider)
          .connect(
            conversationId: state.conversationId,
            financialContext: financialContext,
          );
      _activeStreamingSession = session;
      unawaited(_handleStreamingEvents(session, generation));
    } on StreamingVoiceApiException catch (error) {
      if (_isCurrentCall(generation)) {
        await _fallbackToCloudVoiceCapture(generation, error.message);
      }
      return;
    } on Object {
      if (_isCurrentCall(generation)) {
        await _fallbackToCloudVoiceCapture(
          generation,
          'Could not open Assistant voice stream.',
        );
      }
      return;
    }

    var utteranceEndSent = false;
    void sendUtteranceEndIfNeeded() {
      if (utteranceEndSent) {
        return;
      }
      utteranceEndSent = true;
      session.endUtterance();
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
            sendUtteranceEndIfNeeded();
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
          fail('Could not stream voice audio.');
        } else {
          _deferBackgroundStreamingRestart(session);
        }
      }
      unawaited(session.endSession());
      return;
    }

    if (!_isCurrentCall(generation) || !state.isCallActive) {
      unawaited(session.endSession());
      return;
    }
    if (!capturedAudio) {
      if (state.phase == VoiceCallPhase.thinking ||
          state.phase == VoiceCallPhase.speaking) {
        return;
      }
      unawaited(session.endSession());
      _recoverFromEmptyVoiceTurn('I did not catch that. I am listening again.');
      return;
    }

    endpointUtterance();
    sendUtteranceEndIfNeeded();
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
      fail(streamError);
      return;
    }
    await _captureNextUtterance(generation);
  }

  void _deferBackgroundStreamingRestart(StreamingVoiceSession session) {
    if (identical(_activeStreamingSession, session)) {
      _activeStreamingSession = null;
    }
    _cancelThinkingTimeout();
    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      errorMessage:
          'Assistant could not restart the microphone in the background. Open Assistant to continue.',
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
        fail('Could not capture voice audio.');
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
            financialContext: await _financialContext(),
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
            fail(message);
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
        fail(error.message);
      }
    } on Object {
      if (_isCurrentCall(generation)) {
        fail('Active voice call failed.');
      }
    }
  }

  Future<void> _handleStreamingEvents(
    StreamingVoiceSession session,
    int generation,
  ) async {
    var assistantText = '';
    var responseAudioStarted = false;
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
        onChunkStarted: (_) {
          if (_isCurrentCall(generation)) {
            startSpeaking(assistantText);
            _startBargeInMonitoring(generation);
          }
        },
        onQueueDrained: () {
          _stopBargeInMonitoring();
        },
        onError: (message) {
          _stopBargeInMonitoring();
          if (_isCurrentCall(generation)) {
            fail(message);
          }
        },
      );
    }

    try {
      await for (final event in session.events) {
        if (!_isCurrentCall(generation) || !state.isCallActive) {
          return;
        }

        switch (event.name) {
          case 'session.started':
            break;
          case 'transcript.partial':
            updateTranscript(event.transcript ?? state.currentTranscript);
          case 'transcript.final':
            if (event.speechFinal) {
              assistantText = '';
              responseAudioStarted = false;
              startThinking(finalTranscript: event.transcript);
              unawaited(_activeStreamingCaptureService?.cancel());
            } else {
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
            unawaited(_activeStreamingCaptureService?.cancel());
            if (state.phase != VoiceCallPhase.thinking) {
              startThinking(finalTranscript: state.currentTranscript);
            }
            _armThinkingTimeout(generation);
            beginStreamingAudioIfNeeded();
          case 'assistant.token':
            assistantText += event.token ?? '';
            _armThinkingTimeout(generation);
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
                  );
            }
          case 'assistant.done':
            _cancelThinkingTimeout();
            beginStreamingAudioIfNeeded();
            if (event.conversationId != null) {
              state = state.copyWith(
                conversationId: event.conversationId,
                lastAssistantResponse: event.responseText ?? assistantText,
                clearError: true,
              );
            }
            _streamingPlaybackQueue.finishResponse(
              callbacks: playbackCallbacks(),
            );
            await _streamingPlaybackQueue.waitUntilIdle();
            _stopBargeInMonitoring();
            if (_isCurrentCall(generation) && state.isCallActive) {
              if (state.phase == VoiceCallPhase.speaking) {
                completeSpeaking();
              } else if (state.phase != VoiceCallPhase.listening &&
                  !state.isMuted) {
                resumeListening();
              }
            }
            unawaited(session.endSession());
            return;
          case 'session.ended':
            return;
          case 'session.interrupted':
            break;
          case 'error':
            if (event.errorCode == 'turn_in_progress') {
              _handleTurnInProgressEvent();
              break;
            }
            fail(event.detail ?? 'Assistant voice stream failed.');
            return;
        }
      }
    } on StreamingVoiceApiException catch (error) {
      if (_isCurrentCall(generation)) {
        fail(error.message);
      }
    } on Object {
      if (_isCurrentCall(generation)) {
        fail('Assistant voice stream failed.');
      }
    } finally {
      if (identical(_activeStreamingSession, session)) {
        _activeStreamingSession = null;
      }
    }
  }

  Future<Map<String, dynamic>?> _financialContext() async {
    final service = ref.read(assistantFinancialContextServiceProvider);
    if (service == null) {
      return null;
    }
    try {
      return await service.buildSummary();
    } on Object {
      return null;
    }
  }
}
