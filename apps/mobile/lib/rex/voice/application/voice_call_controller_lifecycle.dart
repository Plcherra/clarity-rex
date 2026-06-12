// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerLifecycle on VoiceCallController {
  Future<void> _handleLifecycleResume() async {
    if (_isHandlingLifecycleResume) {
      return;
    }
    _isHandlingLifecycleResume = true;
    try {
      await _audioSessionService.configureForVoiceTurn();
      await _audioSessionService.preferLoudSpeaker();
      await _backgroundVoiceService.start();
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
