/// Explicit reason for every Listening → Thinking / utterance.end decision.
///
/// Submit authority (production streaming path):
/// - [vadSilence] — local VAD post-speech silence (only genuine mic endpoint)
/// - [speechFinalAfterVad] / [transcriptIdleAfterVad] — complete a turn that
///   already reached VAD silence (STT catch-up only; never a VAD substitute)
/// - [manualStop] — red stop / end-turn control (diagnostic + future Flux handoff)
/// - [chatFallback] — REST chat when streaming cannot complete with a known
///   transcript (not an utterance.end path)
/// - [nativeBridge] — experimental native iOS bridge only
///
/// Never a submit reason:
/// - recorder death, capture cancel, lifecycle, AVAudioSession interruption,
///   route change, WebSocket loss/reconnect, or [maxDurationRollover]
enum VoiceTurnFinalizeReason {
  vadSilence,
  speechFinalAfterVad,
  transcriptIdleAfterVad,
  manualStop,
  chatFallback,
  nativeBridge,
  maxDurationRollover,
}

extension VoiceTurnFinalizeReasonX on VoiceTurnFinalizeReason {
  /// Reasons allowed to emit utterance.end / move Listening → Thinking.
  bool get maySubmitTranscript {
    switch (this) {
      case VoiceTurnFinalizeReason.vadSilence:
      case VoiceTurnFinalizeReason.speechFinalAfterVad:
      case VoiceTurnFinalizeReason.transcriptIdleAfterVad:
      case VoiceTurnFinalizeReason.manualStop:
      case VoiceTurnFinalizeReason.chatFallback:
      case VoiceTurnFinalizeReason.nativeBridge:
        return true;
      case VoiceTurnFinalizeReason.maxDurationRollover:
        return false;
    }
  }

  /// True when this reason is only valid after local VAD silence for the turn.
  bool get requiresPriorVadSilence {
    switch (this) {
      case VoiceTurnFinalizeReason.speechFinalAfterVad:
      case VoiceTurnFinalizeReason.transcriptIdleAfterVad:
        return true;
      case VoiceTurnFinalizeReason.vadSilence:
      case VoiceTurnFinalizeReason.manualStop:
      case VoiceTurnFinalizeReason.chatFallback:
      case VoiceTurnFinalizeReason.nativeBridge:
      case VoiceTurnFinalizeReason.maxDurationRollover:
        return false;
    }
  }

  String get code => name;
}
