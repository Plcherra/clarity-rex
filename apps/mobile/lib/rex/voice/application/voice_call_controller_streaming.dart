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
    if (_pausedForSaveConfirmation || _hasPendingSaveConfirmation()) {
      _pausedForSaveConfirmation = true;
      return;
    }
    if (state.phase == VoiceCallPhase.listening) {
      _cancelThinkingTimeout();
    }
    if (!_isCurrentCall(generation) ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }

    final listenEpoch = ++_streamingListenEpoch;
    if (ref.read(streamingVoiceEnabledProvider)) {
      unawaited(
        _streamNextUtterance(
          generation,
          listenEpoch: listenEpoch,
          initialAudioChunks: initialAudioChunks,
        ),
      );
    } else {
      unawaited(_captureNextUtterance(generation));
    }
  }

  Future<void> _streamNextUtterance(
    int generation, {
    required int listenEpoch,
    List<Uint8List> initialAudioChunks = const [],
  }) async {
    if (!_isCurrentCall(generation) ||
        listenEpoch != _streamingListenEpoch ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      return;
    }

    if (kIsWeb && _activeStreamingSession == null) {
      await _streamNextUtteranceWeb(
        generation,
        listenEpoch: listenEpoch,
        initialAudioChunks: initialAudioChunks,
      );
      return;
    }

    await _streamNextUtteranceConnected(
      generation,
      listenEpoch: listenEpoch,
      initialAudioChunks: initialAudioChunks,
    );
  }
}
