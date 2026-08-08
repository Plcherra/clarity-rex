// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerStreamingEvents on VoiceCallController {
  Future<void> _handleStreamingEvents(StreamingVoiceSession session) async {
    var assistantText = '';
    var responseAudioStarted = false;
    DateTime? assistantStartedAt;
    DateTime? firstAudioChunkAt;
    DateTime? lastAudioChunkStartedAt;
    var streamEndedCleanly = false;
    Completer<void>? streamingDrainCompleter;
    var streamingDrainSpeakText = '';
    var streamingDrainGeneration = 0;
    bool isActiveSession() =>
        identical(_activeStreamingSession, session) && state.isCallActive;

    void beginStreamingAudioIfNeeded() {
      if (responseAudioStarted) {
        return;
      }
      responseAudioStarted = true;
      unawaited(_preparePlaybackAudioSession());
      _streamingPlaybackQueue.beginResponse();
    }

    Future<void> handleStreamingQueueDrained() async {
      final drainCompleter = streamingDrainCompleter;
      if (drainCompleter == null) {
        return;
      }
      try {
        await _handleStreamingQueueDrained(
          speakText: streamingDrainSpeakText,
          generation: streamingDrainGeneration,
        );
      } finally {
        if (!drainCompleter.isCompleted) {
          drainCompleter.complete();
        }
      }
    }

    StreamingAudioPlaybackCallbacks playbackCallbacks() {
      return StreamingAudioPlaybackCallbacks(
        onChunkStarted: (chunk) {
          if (isActiveSession()) {
            final now = DateTime.now();
            firstAudioChunkAt ??= now;
            _markVoiceTurnFirstAudio(_streamingTurnSequence);
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
          unawaited(handleStreamingQueueDrained());
        },
        onError: (message) {
          _stopBargeInMonitoring();
          if (!isActiveSession()) {
            streamingDrainCompleter?.complete();
            return;
          }
          if (streamingDrainCompleter != null &&
              !_streamingPlaybackQueue.hasPlayedChunks &&
              streamingDrainSpeakText.isNotEmpty &&
              !state.isMuted) {
            unawaited(
              _playSynthesizedStreamingFallback(
                streamingDrainSpeakText,
                streamingDrainGeneration,
              ).then((started) {
                if (!isActiveSession()) {
                  return;
                }
                if (!started) {
                  failVoiceApi(const CloudVoiceApiException('playback_failed'));
                }
              }).whenComplete(() {
                streamingDrainCompleter?.complete();
              }),
            );
            return;
          }
          failVoiceApi(CloudVoiceApiException(message));
          streamingDrainCompleter?.complete();
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
              final eventTranscript = (event.transcript ?? '').trim();
              final bufferTranscript = _transcriptBuffer.visible.trim();
              final preferredTranscript = VoiceTranscriptBuffer.preferFullest([
                eventTranscript,
                bufferTranscript,
              ]).trim();
              final alreadyFinalized =
                  _streamingTurnFinalizedSequence == _streamingTurnSequence ||
                  _streamingUtteranceEndSent ||
                  _suppressStaleSpeechFinal;
              // Late speech_final after transcript-idle/VAD finalize must not
              // reset playback or start a second utterance.end (double talk).
              if (alreadyFinalized ||
                  state.phase != VoiceCallPhase.listening) {
                if (preferredTranscript.isNotEmpty &&
                    (_streamingTurnFinalizedSequence ==
                            _streamingTurnSequence ||
                        state.phase == VoiceCallPhase.thinking ||
                        state.phase == VoiceCallPhase.speaking)) {
                  _finalizeVoiceTranscriptInChat(
                    finalTranscript: preferredTranscript,
                  );
                }
                break;
              }
              // Empty speech_final is noise / premature endpoint. Cancelling
              // capture here completes the mic as "no audio" and soft-recovers
              // to Start talking without ever sending the turn.
              if (preferredTranscript.isEmpty) {
                break;
              }
              assistantText = '';
              responseAudioStarted = false;
              if (preferredTranscript != bufferTranscript) {
                updateTranscript(preferredTranscript, isFinal: true);
              }
              _endTurnFromLocalEndpoint(
                _callGeneration,
                preferredTranscript: preferredTranscript,
              );
              if (_streamingTurnFinalizedSequence == _streamingTurnSequence) {
                unawaited(_activeStreamingCaptureService?.cancel());
              }
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
            _markVoiceTurnAssistantStarted(_streamingTurnSequence);
            unawaited(_activeStreamingCaptureService?.cancel());
            await _cancelInFlightPlayback();
            responseAudioStarted = false;
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
              _clearVisibleTranscript();
              if (state.currentTranscript.isNotEmpty) {
                state = state.copyWith(clearCurrentTranscript: true);
              }
            }
          case 'assistant.done':
            final completedText = (event.responseText ?? assistantText).trim();
            if (!responseAudioStarted &&
                !_streamingPlaybackQueue.hasAcceptedChunks) {
              beginStreamingAudioIfNeeded();
            }
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
            streamingDrainSpeakText = _streamingSpeakableText(
              completedText: completedText,
              memoryChanges: event.memoryChanges,
            );
            streamingDrainGeneration = _callGeneration;
            final drainCompleter = Completer<void>();
            streamingDrainCompleter = drainCompleter;
            _streamingPlaybackQueue.finishResponse(
              callbacks: playbackCallbacks(),
            );
            try {
              await Future.wait([
                _streamingPlaybackQueue.waitUntilIdle().timeout(
                  const Duration(seconds: 30),
                ),
                drainCompleter.future,
              ]);
            } on TimeoutException {
              await _streamingPlaybackQueue.cancel();
              if (isActiveSession()) {
                await _handleStreamingQueueDrained(
                  speakText: streamingDrainSpeakText,
                  generation: streamingDrainGeneration,
                );
              }
              if (!drainCompleter.isCompleted) {
                drainCompleter.complete();
              }
            } finally {
              streamingDrainCompleter = null;
              streamingDrainSpeakText = '';
            }
            if (isActiveSession()) {
              // Drain already owns the happy-path resume. Only recover here
              // when playback finished but listening never started.
              if ((state.phase == VoiceCallPhase.thinking ||
                      state.phase == VoiceCallPhase.speaking) &&
                  !_hasActiveStreamingListenCycle()) {
                debugPrint('rex_voice_playback safety_resume_after_done');
                _finishAssistantResponseAndListen();
              } else if (state.phase == VoiceCallPhase.listening &&
                  !_hasActiveStreamingListenCycle()) {
                debugPrint('rex_voice_playback safety_restart_listen_cycle');
                _startListeningCycle(_callGeneration);
              }
            }
            _cancelThinkingTimeout();
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
              if (_resendUtteranceEndWithClientTranscript()) {
                debugPrint('rex_voice_stream empty_audio_resend_transcript');
                break;
              }
              debugPrint('rex_voice_stream empty_audio_recovered');
              _recoverFromEmptyVoiceTurn(voiceL10n.voiceFailureDidNotCatch);
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
          _recoverFromStreamingDisconnect();
        }
      }
    }
  }
}
