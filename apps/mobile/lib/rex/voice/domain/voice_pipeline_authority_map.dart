/// Voice pipeline authority map (streaming production path).
///
/// This is engineering law for agents — not a product doc under docs/.
///
/// ## Event → effect
///
/// | Event | Stop/restart capture | Finalize transcript | utterance.end | Listening→Thinking | WS reconnect | Clear/carry transcript | Start TTS |
/// | --- | --- | --- | --- | --- | --- | --- | --- |
/// | VAD silence (`StreamingCaptureEndKind.vadSilence`) | stop cycle | YES (reason=`vadSilence`) | YES | YES | no | carry→finalize | no |
/// | Max duration | stop + **roll same turn** | NO | NO | no | no | **carry** | no |
/// | Recorder death / abort | restart preserve | NO | NO | no | no | carry | no |
/// | Capture cancel (mute/end) | stop | NO | NO | no | maybe end | clear on end | no |
/// | App inactive/paused/hidden | hold (no finalize) | NO | NO | no | no | carry | no |
/// | App resumed (soft) | maybe restart preserve | NO | NO | no | no | carry | no |
/// | AVAudioSession interruption begin | hold | NO | NO | no | no | carry | no |
/// | AVAudioSession interruption end | recover listen | NO | NO | no | no | carry | no |
/// | Route becomingNoisy | hold | NO | NO | no | no | carry | no |
/// | Transcript idle timer | only if VAD already reached | YES (`transcriptIdleAfterVad`) | YES | YES | no | finalize | no |
/// | Speech-final grace / late speech_final | only if VAD already reached | YES (`speechFinalAfterVad`) | YES | YES | no | finalize | no |
/// | speech_final while mic open | no | NO | NO | no | no | update buffer | no |
/// | empty_audio + known transcript | cancel | chatFallback (REST) | NO (REST) | YES | no | finalize chat | YES (synth) |
/// | WS connect fail | REST fallback capture | via REST/chat | no WS | yes | new connect later | depends | yes |
/// | WS unexpected close | restart listen | NO | NO | no | YES new session | clear on soft recover | no |
/// | assistant.started | cancel capture | already finalized | already sent | ensure thinking | no | keep pending | prep |
/// | assistant.audio_chunk / queue drain | no | no | no | →Speaking→Listening | no | clear on listen | YES |
/// | barge-in | interrupt + new listen | NO (new turn) | no | no | keep if healthy | clear | stop |
/// | Manual endCall / fail | stop all | NO | session.end | idle/failed | close | clear | stop |
///
/// ## Single submit authority
///
/// Production streaming submission enters only through
/// `_finalizeStreamingTurn(reason:)` after `_endTurnFromLocalEndpoint(reason:)`.
/// Allowed submit reasons are listed on [VoiceTurnFinalizeReason.maySubmitTranscript].
/// Recorder death, lifecycle, audio interruption, route change, and WS recovery
/// must never set `StreamingCaptureEndKind.vadSilence`.
abstract final class VoicePipelineAuthorityMap {
  static const submitGate = 'VoiceTurnFinalizeReason.maySubmitTranscript';
  static const captureGate = 'StreamingCaptureEndKind.vadSilence';
}
