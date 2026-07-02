// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerLifecycle on VoiceCallController {
  Future<void> _prepareVoiceAudioEnvironment() async {
    try {
      await _audioSessionService.configureForVoiceTurn();
      await _backgroundVoiceService.start();
    } on Object {
      // Audio session setup should improve reliability, not block voice mode.
    }
  }

  Future<void> _releaseVoiceHardware() async {
    await _stopInterimTranscription();
    _stopNativeVoiceSession();
    _stopBargeInMonitoring();
    final streamingSession = _activeStreamingSession;
    _activeStreamingSession = null;
    _activeStreamingEventsTask = null;

    // Stop mic capture before closing the websocket so late chunks are not
    // sent into a closing socket and browser tracks are released promptly.
    await _streamingCaptureService.cancel();
    await _captureService.cancel();

    streamingSession?.interrupt();

    await Future.wait([
      _streamingPlaybackQueue.cancel(),
      _playbackService.stop(),
      _backgroundVoiceService.stop(),
      _audioSessionService.setActive(false),
      if (streamingSession != null) streamingSession.endSession(),
    ]);
  }
  Future<void> _handleLifecycleResume() async {
    if (_isHandlingLifecycleResume) {
      return;
    }
    _isHandlingLifecycleResume = true;
    try {
      await _audioSessionService.configureForVoiceTurn();
      await _audioSessionService.preferLoudSpeaker();
      if (AppCapabilities.instance.supportsBackgroundVoice) {
        await _backgroundVoiceService.start();
      }
      if (state.isCallActive &&
          state.phase == VoiceCallPhase.thinking &&
          !state.isMuted) {
        _armThinkingTimeout(_callGeneration);
      }
      if (!state.isCallActive ||
          state.phase != VoiceCallPhase.listening ||
          state.isMuted) {
        return;
      }

      if (_finishPendingStreamingUtteranceOnResume()) {
        return;
      }

      final generation = ++_callGeneration;
      await _captureService.cancel();
      await _streamingCaptureService.cancel();
      _stopBargeInMonitoring();
      final streamingSession = _activeStreamingSession;
      _activeStreamingSession = null;
      _activeStreamingEventsTask = null;
      streamingSession?.interrupt();
      unawaited(streamingSession?.endSession());

      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        isCapturingSpeech: false,
        clearCurrentTranscript: true,
        clearError: true,
      );
      _clearVisibleTranscript();
      _startListeningCycle(generation);
    } finally {
      _isHandlingLifecycleResume = false;
    }
  }

  bool _finishPendingStreamingUtteranceOnResume() {
    if (!ref.read(streamingVoiceEnabledProvider)) {
      return false;
    }
    final streamingSession = _activeStreamingSession;
    if (streamingSession == null || state.currentTranscript.trim().isEmpty) {
      return false;
    }

    unawaited(_streamingCaptureService.cancel());
    endpointUtterance();
    streamingSession.endUtterance();
    return true;
  }
}
