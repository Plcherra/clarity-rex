# Raw brain deletion — shipped

**Status:** Shipped (July 2026)  
**Result:** Grok receives conversation history + on-demand context only. No personality layer, memory-discipline system prompt, action-truth system prompt, voice “brain instructions”, or proactive monitoring guard.

---

## Deleted

| Module / constant | Notes |
| --- | --- |
| `brain_prompt_policy.py` | Removed mode switch (`production` / `raw` / `raw_truth`) |
| `proactive_insight_guard.py` | Proactive monitoring system append |
| `REX_PERSONALITY_PROMPT` | `prompt_constants.py` |
| `MEMORY_DISCIPLINE_PROMPT` | `prompt_constants.py` |
| `VOICE_RESPONSE_INSTRUCTIONS` | `voice_stream_config.py` |
| `REX_BRAIN_PROMPT_MODE` | `config.py` / `.env.example` |
| `REX_VOICE_INSTRUCTIONS_ENABLED` | `config.py` / `.env.example` |

---

## Kept (not “brain instructions”)

- On-demand context: time, Knows, goals, finance, recall labels, open threads
- Runtime truth guard: `ChatResponseTruthService` / `action_truth_policy.py` (post-LLM, not system prompt)
- Turn short-circuits + companion proposal settings + continuation after confirm/dismiss
- Voice token caps (`VOICE_RESPONSE_MAX_TOKENS`) and low-confidence transcript note only

---

## VPS deploy

1. Pull latest `main`
2. Restart rex-api: `sudo systemctl restart clarity-rex`
3. **Remove** from `/opt/clarity/shared/rex-api.env` if present:
   - `REX_BRAIN_PROMPT_MODE`
   - `REX_VOICE_INSTRUCTIONS_ENABLED`
4. No mobile redeploy required

---

## Local dev

Restart `uvicorn` after pull. Remove those env vars from local `services/rex-api/.env` — they no longer exist.
