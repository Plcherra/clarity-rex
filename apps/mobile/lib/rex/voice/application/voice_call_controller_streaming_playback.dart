// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerStreamingPlayback on VoiceCallController {
  Future<void> _preparePlaybackAudioSession() async {
    await _audioSessionService.configureForVoiceTurn();
    await _audioSessionService.preferLoudSpeaker();
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
    int turnSequence,
  ) {
    if (_streamingUtteranceEndSent) {
      return;
    }
    _streamingUtteranceEndSent = true;
    unawaited(
      _financialContextForUtterance(state.currentTranscript).then((
        financialContext,
      ) {
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

  void _prefetchFinancialContextIfNeeded(String transcript) {
    final normalized = transcript.trim();
    if (normalized.isEmpty ||
        !shouldAttachAssistantFinancialContext(normalized)) {
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
