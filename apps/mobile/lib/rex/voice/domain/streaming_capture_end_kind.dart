/// Why one mic capture cycle completed.
///
/// Only [vadSilence] may authorize transcript submission. Other kinds must not
/// masquerade as conversational silence.
enum StreamingCaptureEndKind {
  /// Controller cancelled the recorder (mute, end call, restart).
  cancelled,

  /// Stream died / errored (screenshot, route blip) — not an endpoint.
  aborted,

  /// No-speech timeout with empty capture.
  noSpeech,

  /// Local VAD silence window closed speech — the only submit-capable end.
  vadSilence,

  /// Hit max utterance duration while still in the same logical turn.
  /// Must roll capture forward; must not send utterance.end mid-sentence.
  maxDuration,
}

extension StreamingCaptureEndKindX on StreamingCaptureEndKind {
  bool get mayAuthorizeSubmit => this == StreamingCaptureEndKind.vadSilence;

  bool get isAbnormalDeath =>
      this == StreamingCaptureEndKind.aborted ||
      this == StreamingCaptureEndKind.cancelled;
}
