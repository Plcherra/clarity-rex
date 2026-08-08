// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerStreamingPlayback on VoiceCallController {
  String _streamingSpeakableText({
    required String completedText,
    Map<String, dynamic>? memoryChanges,
  }) {
    final text = completedText.trim();
    if (text.isNotEmpty) {
      return text;
    }
    final proposals = memoryChanges?['write_proposals'];
    if (proposals is! List) {
      return '';
    }
    for (final entry in proposals) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final status = (entry['status'] as String? ?? 'pending').toLowerCase();
      if (status != 'pending') {
        continue;
      }
      final confirmation = (entry['confirmation_text'] as String? ?? '').trim();
      if (confirmation.isNotEmpty) {
        return confirmation;
      }
      final title = (entry['title'] as String? ?? '').trim();
      if (title.isNotEmpty) {
        return title;
      }
    }
    return '';
  }

  Future<void> _preparePlaybackAudioSession() async {
    await _audioSessionService.configureForVoiceTurn();
    await _audioSessionService.preferLoudSpeaker();
  }

  Future<void> _cancelInFlightPlayback() async {
    await _playbackService.stop();
    await _streamingPlaybackQueue.cancel();
  }

  Future<void> _handleStreamingQueueDrained({
    required String speakText,
    required int generation,
  }) async {
    if (!state.isCallActive) {
      return;
    }

    _stopBargeInMonitoring();
    _logVoiceTurnTimingIfNeeded(_streamingTurnSequence);

    if (_streamingPlaybackQueue.hasAcceptedChunks) {
      _completeStreamingResponseAfterPlayback();
      return;
    }

    if (speakText.isNotEmpty && !state.isMuted) {
      final fallbackStarted = await _playSynthesizedStreamingFallback(
        speakText,
        generation,
      );
      if (!state.isCallActive) {
        return;
      }
      if (!fallbackStarted) {
        failVoiceApi(const CloudVoiceApiException('playback_failed'));
      }
      return;
    }

    _completeStreamingResponseAfterPlayback();
  }

  void _completeStreamingResponseAfterPlayback() {
    if (!state.isCallActive) {
      return;
    }
    if (state.phase == VoiceCallPhase.speaking ||
        state.phase == VoiceCallPhase.thinking) {
      _finishAssistantResponseAndListen();
      debugPrint('rex_voice_playback listening_resumed');
      return;
    }
    if (state.phase == VoiceCallPhase.listening &&
        !_hasActiveStreamingListenCycle()) {
      _startListeningCycle(_callGeneration);
      debugPrint('rex_voice_playback listening_resumed');
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
        return false;
      }
      if (response.audioBase64.isEmpty) {
        return false;
      }

      await _preparePlaybackAudioSession();
      startSpeaking(responseText);
      _startBargeInMonitoring(generation);
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
            resumeListening();
          }
        },
      );
      return true;
    } on Object {
      return false;
    }
  }

  void _sendStreamingUtteranceEndIfNeeded(
    StreamingVoiceSession session,
    int turnSequence, {
    String? transcript,
  }) {
    if (_streamingUtteranceEndSent) {
      return;
    }
    _streamingUtteranceEndSent = true;
    final utteranceTranscript =
        (transcript ?? _pendingUtteranceTranscript ?? _transcriptBuffer.visible)
            .trim();
    if (turnSequence != _streamingTurnSequence ||
        !identical(_activeStreamingSession, session) ||
        !state.isCallActive) {
      return;
    }

    final writeConfirmation = ref
        .read(chatProvider.notifier)
        .writeConfirmationForAffirmation(utteranceTranscript);
    final readyFinance =
        _readyFinancialContextForUtterance(utteranceTranscript);
    final needsFinance = _shouldAttachFinancialContext(utteranceTranscript);

    // Non-finance (or prefetch already ready): send utterance.end immediately.
    // Only await a cold finance build when this turn clearly needs money context.
    if (!needsFinance || readyFinance != null) {
      _markVoiceTurnUtteranceEnd(turnSequence);
      session.endUtterance(
        financialContext: readyFinance,
        writeConfirmation: writeConfirmation,
      );
      return;
    }

    unawaited(
      _financialContextForUtterance(utteranceTranscript).then((
        financialContext,
      ) {
        if (turnSequence != _streamingTurnSequence ||
            !identical(_activeStreamingSession, session) ||
            !state.isCallActive) {
          return;
        }
        _markVoiceTurnUtteranceEnd(turnSequence);
        session.endUtterance(
          financialContext: financialContext,
          writeConfirmation: writeConfirmation,
        );
      }),
    );
  }

  void _prefetchFinancialContextIfNeeded(String transcript) {
    final normalized = transcript.trim();
    if (normalized.isEmpty || !_shouldAttachFinancialContext(normalized)) {
      return;
    }
    if (_prefetchedFinancialContextTranscript == normalized &&
        (_prefetchedFinancialContext != null ||
            _prefetchedFinancialContextTask != null)) {
      return;
    }
    _prefetchedFinancialContextTranscript = normalized;
    _prefetchedFinancialContext = null;
    _prefetchedFinancialContextTask = _financialContext(normalized).then((
      value,
    ) {
      _prefetchedFinancialContext = value;
      return value;
    });
  }

  void _resetPrefetchedFinancialContext() {
    _prefetchedFinancialContext = null;
    _prefetchedFinancialContextTask = null;
    _prefetchedFinancialContextTranscript = null;
  }

  /// Cached finance context only — returns null if prefetch is still in flight.
  Map<String, dynamic>? _readyFinancialContextForUtterance(String transcript) {
    final normalized = transcript.trim();
    if (normalized.isEmpty || !_shouldAttachFinancialContext(normalized)) {
      return null;
    }
    if (_prefetchedFinancialContextTranscript == normalized) {
      return _prefetchedFinancialContext;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _financialContextForUtterance(
    String transcript,
  ) async {
    final normalized = transcript.trim();
    if (_prefetchedFinancialContextTranscript == normalized) {
      final cached = _prefetchedFinancialContext;
      if (cached != null) {
        return cached;
      }
      final task = _prefetchedFinancialContextTask;
      if (task != null) {
        return task;
      }
    }
    return _financialContext(normalized);
  }

  bool _shouldAttachFinancialContext(String transcript) {
    final chatMessages = ref.read(chatProvider).messages;
    return shouldAttachAssistantFinancialContext(
      transcript,
      recentTurnTexts: priorTurnTextsForFinanceAttach(
        chatMessages.map((m) => m.content),
        currentMessage: transcript,
      ),
    );
  }

  Future<Map<String, dynamic>?> _financialContext([String? transcript]) async {
    if (transcript == null || !_shouldAttachFinancialContext(transcript)) {
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
      return await service.buildSummary(userMessage: transcript);
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
