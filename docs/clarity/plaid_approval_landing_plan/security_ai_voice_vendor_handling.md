# Clarity Security AI And Voice Vendor Handling

Status: File 06 Phase 5 AI and voice vendor handling approved for initial landing launch draft.

Purpose: define public `/security` page language explaining how Rex, AI model providers, speech-to-text providers, and text-to-speech providers may process information to provide chat and voice features.

This contract supports the `/security` page section titled `AI and voice processing`.

## Section Goal

The AI and voice section should help users and Plaid reviewers understand:

- Rex is the AI assistant inside Clarity.
- Rex may use Clarity context to answer user questions.
- AI providers may process relevant prompts, conversation content, product context, and metadata.
- Voice features may involve audio, transcripts, generated responses, text-to-speech output, and related metadata.
- Voice is user-initiated and should not be described as continuously listening.
- AI and voice provider retention or training-use claims require verification before publication.

The section should be transparent without making the product sound unsafe or mysterious.

## Recommended Section Title

Preferred:

- `AI and voice processing`

Acceptable alternatives:

- `How Rex uses AI and voice services`
- `Rex, chat, and voice data handling`
- `AI assistant and voice providers`

Avoid:

- `Always-on listening`
- `Rex bank access`
- `AI surveillance`
- `Voice recording guarantees`

## Plain-Language Summary

Recommended draft:

> Rex is the AI assistant inside Clarity. To provide chat and voice features, Clarity may process conversation content, voice-derived text, generated responses, product context, and related metadata with AI, speech-to-text, and text-to-speech service providers.

Recommended follow-up:

> Rex may use approved Clarity context, such as budgets, spending summaries, goals, memory/context, and conversation history, but Rex does not connect directly to banks outside Clarity's user-authorized account connection flow.

## AI Model Provider Processing

Recommended copy:

> Clarity may send relevant prompts, conversation content, user-selected context, authorized financial context, and related metadata to AI model providers to generate Rex responses.

Must convey:

- Rex responses are generated through AI model services.
- Relevant Clarity context may be included when needed.
- Context may include financial summaries, budgets, goals, memory/context, and conversation history.
- AI outputs may be incomplete or inaccurate and should be reviewed for important decisions.

Known current provider examples to verify before launch:

- xAI/Grok for model responses.

Do not publish unless verified:

- Exact model names if they may change.
- Zero-retention claims.
- Training opt-out status.
- Provider data-residency details.
- Provider-specific security certifications.
- Exact prompt/token logging behavior.

## Speech-To-Text Processing

Recommended copy:

> When a user starts a voice interaction, Clarity may process audio or audio-derived data with a speech-to-text provider to convert spoken words into text for Rex.

Must convey:

- Voice input is user-initiated.
- Speech-to-text may process audio or audio-derived content.
- Transcripts may be imperfect.
- Background noise, device routing, accent, connectivity, and provider availability can affect results.

Known current provider examples to verify before launch:

- Deepgram for speech-to-text.

Do not say:

- Rex is continuously listening.
- Audio is never processed by a vendor.
- Raw audio is never stored or retained unless verified.
- Transcription is perfect.

## Text-To-Speech Processing

Recommended copy:

> Clarity may use a text-to-speech provider to turn Rex's generated text response into spoken audio.

Must convey:

- TTS converts generated response text into audio.
- TTS providers may process text and related request metadata.
- Spoken output can depend on device routing, volume, provider availability, and network conditions.

Known current provider examples to verify before launch:

- Google Text-to-Speech for spoken responses.

Do not say:

- TTS providers never process response text.
- Audio output is guaranteed through a specific device route.
- Voice is always available.

## Data Types To Distinguish

The public page should distinguish these concepts:

- `Audio input`: sound captured during a user-initiated voice interaction.
- `Transcript`: text produced from speech-to-text processing.
- `Prompt/context`: user message plus relevant Clarity context used to generate a Rex response.
- `Generated response`: Rex's text response.
- `Spoken response`: audio created from text-to-speech processing.
- `Voice metadata`: technical details needed for reliability, troubleshooting, timing, or support.

Do not collapse all of these into a vague phrase like `voice data` without explanation.

## Retention And Storage Boundary

Recommended copy:

> Clarity may retain transcripts, generated responses, conversation history, memory/context, and related metadata where needed to provide Rex, conversation history, reliability, support, security, or user-reviewable memory. Raw audio handling and vendor retention should be verified before publishing exact retention claims.

Must align with:

- `privacy_retention_and_deletion.md`
- `privacy_sharing_and_vendors.md`
- `terms_ai_assistant_disclaimer.md`

Do not publish unless verified:

- Raw audio is never stored.
- Raw audio is deleted immediately.
- Vendors never retain audio, transcripts, prompts, or outputs.
- AI/voice providers never train on data.
- Exact retention timelines.

## Rex And Financial Data Boundary

Recommended copy:

> Rex may use Clarity context to answer questions about spending, budgets, goals, and product context. Rex does not independently access financial institutions, move money, open accounts, apply for credit, file taxes, make purchases, or execute transactions.

Must convey:

- Rex uses Clarity context, not direct bank access.
- Rex does not take autonomous financial actions.
- Users remain responsible for decisions and actions.

## Public Copy Block

This block can be adapted directly for the `/security` page:

> Rex is the AI assistant inside Clarity. To provide Rex chat and voice features, Clarity may process conversation content, voice-derived text, generated responses, approved product context, and related metadata with AI, speech-to-text, and text-to-speech service providers.

Optional second paragraph:

> Voice interactions are user-initiated. Speech-to-text may process audio or audio-derived content to create a transcript, and text-to-speech may process Rex's generated response text to create spoken audio. Transcripts and spoken responses may be imperfect due to background noise, device routing, connection issues, or provider availability.

Optional boundary paragraph:

> Rex may use approved Clarity context, but Rex does not connect directly to financial institutions or take financial actions for users.

## What Not To Expose

Do not include:

- API keys or vendor credentials.
- Voice endpoint URLs.
- Model routing prompts.
- System prompts.
- Raw transcripts from real users.
- Audio samples from real users.
- Provider dashboard screenshots.
- Internal latency logs tied to identifiable users.
- Service account file paths.
- Model debug traces.

Allowed:

- Provider categories.
- High-level known provider names after verification.
- Public explanation of audio, transcript, prompt/context, generated response, spoken response, and metadata.

## Plaid-Friendly Wording

Use:

- `Rex is the AI assistant inside Clarity`
- `user-initiated voice interaction`
- `speech-to-text`
- `text-to-speech`
- `conversation content`
- `voice-derived text`
- `approved Clarity context`
- `authorized financial context`
- `service providers`

Avoid:

- `Rex listens all the time`
- `always listening`
- `Rex connects to your bank`
- `Rex manages your money`
- `AI has full bank access`
- `we never send data to vendors`
- `vendors never retain data`
- `perfect transcription`
- `guaranteed voice availability`

## Claims That Require Verification

Do not publish these without implementation and vendor verification:

- Whether raw audio is stored by Clarity.
- Whether raw audio is stored by speech providers.
- Whether transcripts are retained by Clarity.
- Whether prompts/outputs are retained by AI providers.
- Whether providers train on submitted data.
- Whether provider retention settings are configurable.
- Exact AI, speech, or TTS model names.
- Exact retention periods.
- Exact deletion workflows for provider-side data.
- Exact audio-device routing behavior.

## Cross-Links

This section should link to:

- `/privacy` for data categories, vendor processing, retention, and user rights.
- `/terms` for AI response accuracy, user responsibility, and no-autonomous-action boundaries.
- `/data-deletion` for deletion requests.
- `/contact` for voice, privacy, or security questions.

## Implementation Review Questions

Before publishing, verify:

- Which AI model provider is used in production?
- Which speech-to-text provider is used in production?
- Which text-to-speech provider is used in production?
- Does Clarity store raw audio, transcripts, generated responses, and/or metadata?
- What provider retention/training settings apply?
- Does voice start only from user action?
- Does this section match app behavior for chat, voice, memory, and conversation history?
- Does the wording avoid implying Rex connects directly to banks?

## Acceptance Checklist

- Explains AI and voice services may process conversation/audio-derived content to provide Rex.
- Distinguishes audio, transcripts, prompts/context, generated responses, spoken responses, and metadata.
- Links Privacy Policy and related Terms/Data Deletion/Contact pages.
- States voice is user-initiated and avoids `always listening` language.
- Avoids unverified raw-audio, vendor-retention, provider-training, and zero-retention claims.
- Makes clear Rex does not connect directly to financial institutions or take financial actions for users.
