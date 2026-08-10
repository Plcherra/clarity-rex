// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerStreamingCapture on VoiceCallController {
  Future<void> _streamNextUtteranceConnected(
    int generation, {
    required int listenEpoch,
    List<Uint8List> initialAudioChunks = const [],
    bool preserveTranscript = false,
  }) async {
    if (listenEpoch != _streamingListenEpoch) {
      return;
    }
    _streamingListenEpochInFlight = true;
    try {
      late final StreamingVoiceSession session;
      if (!_streamingSessionIsConnected()) {
        final staleSession = _activeStreamingSession;
        if (staleSession != null) {
          _activeStreamingSession = null;
          _activeStreamingEventsTask = null;
          unawaited(staleSession.endSession());
        }
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
          debugPrint('rex_voice_stream connect_failed ${error.message}');
          if (_isCurrentCall(generation)) {
            await _fallbackToCloudVoiceCapture(generation, error.message);
          }
          return;
        } on Object {
          debugPrint('rex_voice_stream connect_failed_unknown');
          if (_isCurrentCall(generation)) {
            await _fallbackToCloudVoiceCapture(
              generation,
              voiceL10n.voiceErrorOpenAssistantStreamFailed,
            );
          }
          return;
        }
      } else {
        session = _activeStreamingSession!;
      }

      if (listenEpoch != _streamingListenEpoch) {
        return;
      }

      if (preserveTranscript) {
        // Same turn after screenshot/background — keep bubble + buffer.
        _streamingUtteranceEndSent = false;
      } else {
        final turnSequence = ++_streamingTurnSequence;
        _streamingUtteranceEndSent = false;
        _beginVoiceTurn(turnSequence);
        _resetPrefetchedFinancialContext();
      }
      for (final chunk in initialAudioChunks) {
        session.sendAudioChunk(chunk);
      }
      if (initialAudioChunks.isNotEmpty) {
        startCapturingSpeech();
      }

      final StreamingUtteranceCaptureResult captureResult;
      try {
        captureResult = await _streamingCaptureService.streamUtterance(
          config: ref.read(voiceCaptureConfigProvider),
          onReady: () {
            if (_isCurrentCall(generation) &&
                listenEpoch == _streamingListenEpoch &&
                state.phase == VoiceCallPhase.listening) {
              _markListeningReady();
              _armNoSpeechTimeout(generation);
            }
          },
          onSpeechStart: () {
            if (_isCurrentCall(generation) &&
                listenEpoch == _streamingListenEpoch &&
                state.phase == VoiceCallPhase.listening) {
              startCapturingSpeech();
            }
          },
          onSpeechEnded: () {
            if (_isCurrentCall(generation) &&
                listenEpoch == _streamingListenEpoch &&
                state.phase == VoiceCallPhase.listening) {
              // VAD silence window closed — mic speech is over even if STT lags.
              state = state.copyWith(isCapturingSpeech: false);
              _markVoiceTurnCaptureEnd(_streamingTurnSequence);
              _markVadSilenceReached(source: 'onSpeechEnded');
              _endTurnFromLocalEndpoint(
                generation,
                reason: VoiceTurnFinalizeReason.vadSilence,
              );
            }
          },
          onAudioChunk: (chunk) async {
            if (_isCurrentCall(generation) &&
                listenEpoch == _streamingListenEpoch) {
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

      await _handleStreamingCaptureResult(
        captureResult,
        generation: generation,
        listenEpoch: listenEpoch,
        session: session,
      );
    } finally {
      if (listenEpoch == _streamingListenEpoch) {
        _streamingListenEpochInFlight = false;
      }
    }
  }

  Future<void> _streamNextUtteranceWeb(
    int generation, {
    required int listenEpoch,
    List<Uint8List> initialAudioChunks = const [],
    bool preserveTranscript = false,
  }) async {
    if (listenEpoch != _streamingListenEpoch) {
      return;
    }
    _streamingListenEpochInFlight = true;
    try {
    StreamingVoiceSession? session;
    final pendingChunks = <Uint8List>[...initialAudioChunks];
    if (preserveTranscript) {
      _streamingUtteranceEndSent = false;
    } else {
      final turnSequence = ++_streamingTurnSequence;
      _streamingUtteranceEndSent = false;
      _beginVoiceTurn(turnSequence);
      _resetPrefetchedFinancialContext();
    }

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
          listenEpoch != _streamingListenEpoch ||
          state.phase != VoiceCallPhase.listening) {
        return;
      }
      final activeSession = session ?? _activeStreamingSession;
      if (activeSession == null) {
        return;
      }
      _markListeningReady();
      _armNoSpeechTimeout(generation);
    }

    // Open the mic before any network I/O so browser user activation is still
    // valid when the user just tapped start voice on web.
    final captureFuture = _streamingCaptureService.streamUtterance(
      config: ref.read(voiceCaptureConfigProvider),
      onReady: notifyListeningReady,
      onSpeechStart: () {
        if (_isCurrentCall(generation) &&
            listenEpoch == _streamingListenEpoch &&
            state.phase == VoiceCallPhase.listening) {
          startCapturingSpeech();
        }
      },
      onSpeechEnded: () {
        if (_isCurrentCall(generation) &&
            listenEpoch == _streamingListenEpoch &&
            state.phase == VoiceCallPhase.listening) {
          state = state.copyWith(isCapturingSpeech: false);
          _markVoiceTurnCaptureEnd(_streamingTurnSequence);
          _markVadSilenceReached(source: 'onSpeechEnded');
          _endTurnFromLocalEndpoint(
            generation,
            reason: VoiceTurnFinalizeReason.vadSilence,
          );
        }
      },
      onAudioChunk: (chunk) async {
        if (!_isCurrentCall(generation) || listenEpoch != _streamingListenEpoch) {
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

    final StreamingUtteranceCaptureResult captureResult;
    try {
      captureResult = await captureFuture;
    } on Object {
      if (_isCurrentCall(generation)) {
        failL10n((l10n) => l10n.voiceErrorStreamVoiceAudioFailed);
      }
      if (!identical(_activeStreamingSession, session)) {
        unawaited(session?.endSession());
      }
      return;
    }

    await _handleStreamingCaptureResult(
      captureResult,
      generation: generation,
      listenEpoch: listenEpoch,
      session: session,
    );
    } finally {
      if (listenEpoch == _streamingListenEpoch) {
        _streamingListenEpochInFlight = false;
      }
    }
  }
}
