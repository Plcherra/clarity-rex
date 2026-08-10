// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerStreamingTurn on VoiceCallController {
  void _startListeningCycle(
    int generation, {
    List<Uint8List> initialAudioChunks = const [],
  }) {
    _startListeningCycleInternal(
      generation,
      initialAudioChunks: initialAudioChunks,
      preserveTranscript: false,
    );
  }

  /// Restart mic after screenshot/background without wiping the live bubble.
  void _startListeningCyclePreservingTranscript(int generation) {
    _startListeningCycleInternal(
      generation,
      preserveTranscript: true,
    );
  }

  void _startListeningCycleInternal(
    int generation, {
    List<Uint8List> initialAudioChunks = const [],
    required bool preserveTranscript,
  }) {
    if (_isUsingNativeVoice) {
      return;
    }
    if (_blockListenForSaveConfirmation ||
        _pausedForSaveConfirmation ||
        _hasPendingSaveConfirmation()) {
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
    // Claim the cycle immediately so assistant.done's safety restart cannot
    // bump the epoch again before the async capture body sets inFlight.
    _streamingListenEpochInFlight = true;
    _suppressStaleSpeechFinal = false;
    if (ref.read(streamingVoiceEnabledProvider)) {
      unawaited(
        _streamNextUtterance(
          generation,
          listenEpoch: listenEpoch,
          initialAudioChunks: initialAudioChunks,
          preserveTranscript: preserveTranscript,
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
    bool preserveTranscript = false,
  }) async {
    if (!_isCurrentCall(generation) ||
        listenEpoch != _streamingListenEpoch ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      if (listenEpoch == _streamingListenEpoch) {
        _streamingListenEpochInFlight = false;
      }
      return;
    }

    if (kIsWeb && _activeStreamingSession == null) {
      await _streamNextUtteranceWeb(
        generation,
        listenEpoch: listenEpoch,
        initialAudioChunks: initialAudioChunks,
        preserveTranscript: preserveTranscript,
      );
      return;
    }

    await _streamNextUtteranceConnected(
      generation,
      listenEpoch: listenEpoch,
      initialAudioChunks: initialAudioChunks,
      preserveTranscript: preserveTranscript,
    );
  }
}
