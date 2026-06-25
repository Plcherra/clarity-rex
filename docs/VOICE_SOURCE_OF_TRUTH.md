# Rex Voice Source Of Truth

This document records the MVP voice architecture for Clarity.

## MVP Status

Plan 5 voice and usage code is complete for MVP. Real-device smoke still needs
to confirm microphone capture, streaming WebSocket behavior, playback, app
background/resume, and usage totals after an actual voice session.

## Production Voice Path

The MVP production path is:

```text
Mobile inline voice panel
-> Streaming voice over Rex API WebSocket `/voice/stream`
-> Deepgram streaming STT
-> ChatService / Simple Rex Brain
-> Google TTS
-> Mobile streaming audio playback
```

Voice and chat must use the same production Rex Brain behavior. Voice is an
input/output mode, not a separate assistant.

## Fallback Path

If streaming voice is disabled or the WebSocket cannot open, mobile can fall
back to the REST cloud voice path:

```text
Mobile captured utterance
-> Rex API `/voice/turn`
-> Deepgram STT
-> ChatService / Simple Rex Brain
-> Google TTS
-> Mobile audio playback
```

This fallback is acceptable for MVP because it still uses backend STT/TTS and
the same `ChatService` path.

## Deferred / Experimental Paths

Native iOS voice bridge is experimental.

- Release builds should not rely on `REX_NATIVE_IOS_VOICE_ENABLED`.
- The legacy flag is intentionally ignored.
- `REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED` is only for native bridge
  experiments.
- Native voice must not become a second Rex Brain.

Local/on-device speech recognition may be used only for interim UX. It must not
save memory, answer, or perform actions outside the backend Rex path.

## Runtime Flags

| Flag | MVP default | Meaning |
| --- | --- | --- |
| `REX_CLOUD_VOICE_ENABLED` | `true` | Enables backend voice fallback. |
| `REX_STREAMING_VOICE_ENABLED` | `true` | Enables WebSocket streaming voice. |
| `REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED` | `false` | Native bridge experiments only. |
| `REX_NATIVE_IOS_VOICE_ENABLED` | ignored | Legacy flag; do not use for release. |

## Usage Tracking

Backend usage tracking records:

- STT turns.
- TTS turns.
- LLM turns.
- Voice session duration.

The Profile voice usage screen currently reads `user_voice_summaries` directly
from Supabase. Rex API also exposes `/usage/me`; keep the Supabase summary view
as the MVP user-facing source unless a later product decision moves usage reads
behind Rex API.

## User-Facing Failure States

The inline voice panel should explain:

- Microphone permission issues.
- Microphone capture/start failures.
- Empty/no-audio turns.
- Voice stream or connection drop.
- Unreadable transcript.
- TTS or playback failures.
- Generic paused/retry state.

The user should always have a retry path. Settings should be offered when the
failure is permission-related.

Repeated no-speech recoveries should be capped. Rex may auto-listen again after
short silence, but a silent microphone should eventually stop in a retryable
state instead of cycling forever.

## MVP Acceptance

Voice is MVP-ready when:

- Streaming voice works in the release build.
- REST fallback works when streaming is unavailable.
- Chat and voice produce consistent Rex behavior.
- Memory and finance truth rules are identical to chat.
- Usage totals update after voice sessions.
- Experimental/native paths are not presented as the release path.
