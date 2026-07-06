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
}
