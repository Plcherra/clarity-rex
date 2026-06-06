# Clarity Product Vocabulary

Status: Phase 2 prebuild naming contract  
Last updated: 2026-06-06  
Scope: product, UI, backend-facing copy, documentation, and regression scans for one-app Clarity language.

## Executive Summary

Clarity is the product. Assistant is a capability inside Clarity. Rex is the conversational personality/name the user may speak to, not a separate app, product, backend, memory system, or UI surface.

All user-facing language should make Clarity feel like one financial clarity app with an assistant built in. Old implementation language such as pending memory, memory candidates, review sessions, and backend review terminology must not appear in the product UI.

## Core Naming Rules

| Concept | Use | Do not use |
| --- | --- | --- |
| Product/app | Clarity | Rex app, Rex product |
| Assistant feature | Assistant, Clarity Assistant | Rex tab, Rex app, Rex backend in UI |
| Conversational name | Rex, only in chat/voice dialogue | Rex as product shell, settings area, memory screen, or API brand |
| User information | What Clarity Knows, My Information, saved information | Memory candidates, pending memory, review queue |
| Financial accounts | Connected accounts, connected institutions | CSV accounts as primary app model |
| Transactions | Activity, transactions, synced activity | Imported-only activity |
| Plaid entry | Connect bank, connected institution, sync, reconnect, disconnect | Upload CSV to get started as primary copy |
| CSV fallback | Import CSV instead, CSV import fallback | CSV-first, CSV-only |
| Goals | Goals, guidance, commitments when legally/semantically correct | Rex plans as product feature |
| Usage tracking | Usage event, internal usage, latency, status, feature usage | Raw prompt logs, transcript logs, audio logs |

## Where Rex May Appear

Rex may appear only when the app is clearly representing the assistant's conversational personality:

- User messages that address the assistant, such as "Hey Rex."
- Assistant dialogue where the personality name is natural.
- Voice/TTS persona references.
- Internal implementation filenames that are scheduled for later cleanup and are not user-facing.
- Historical docs, archived migrations, and old-plan references when they are clearly describing removed behavior.

Rex must not appear as a product-level label:

- Bottom navigation labels
- App title, onboarding, settings, privacy, account, or data screens
- "What Clarity Knows" / user information surfaces
- Public API titles or external docs
- Empty states that describe what the app can do
- Badges such as "Rex knows this" in product UI

## Required Product Labels

| Surface | Preferred label | Notes |
| --- | --- | --- |
| Main app | Clarity | One app identity across mobile, docs, backend-facing copy, and release materials. |
| Assistant nav | Assistant | The feature may contain Rex's conversation, but the nav label should stay product-neutral. |
| Knowledge tab | Knows, What Clarity Knows, My Information | Avoid "Memory" as the primary product label. |
| Knowledge items | Saved, saved information, user information | Avoid backend record terms. |
| Corrections | Update, corrected, changed, replaced | Corrections should sound like normal editing. |
| Accounts | Connected accounts, institutions | Plaid is the primary connection model. |
| CSV | Import CSV instead | CSV is fallback, not the default journey. |
| Usage | Internal usage, usage events, daily usage | Never imply raw-content monitoring. |

## Banned User-Facing Terms

These terms must not appear in active product UI or assistant-facing user copy:

| Banned term | Replace with |
| --- | --- |
| Rex app | Clarity |
| Rex Backend | Clarity API or backend service |
| What Rex knows | What Clarity Knows |
| Rex knows this | Saved |
| Message Rex | Message Assistant, Message Clarity, or context-specific input copy |
| Pending memory | Saved information, or remove the pending concept entirely |
| Memory candidate | Saved information |
| Review session | Review, if user-facing review is truly needed; otherwise remove |
| Candidate card | Information card |
| Backend review | Internal review, only in internal docs if needed |
| Save this only after approval | Save, Update, or Do not save |
| Review before saving | Confirm update, only for sensitive changes |
| CSV-first | CSV fallback |

## Context Rules

### App Shell

Use Clarity as the app identity and keep top-level navigation concise: Dashboard, Accounts, Budgets, Assistant, Profile. Do not make Assistant feel like a second app inside Clarity.

### Assistant Conversation

Rex can speak naturally as the assistant personality, but the surrounding product chrome should remain Clarity/Assistant language. The assistant may say "Got it" or "I'll remember that" in conversation, but saved data screens should say "Saved" or "What Clarity Knows."

### User Information

User information is direct, editable, and durable. Use "What Clarity Knows" or "My Information." Corrections should update existing records instead of creating review/pending artifacts.

### Financial Product

Plaid-connected institutions are the primary data path. CSV remains visible as "Import CSV instead" for fallback and portability.

### Usage Tracking

Usage tracking is internal/admin first. Store counts, timing, status, feature names, channels, and sanitized metadata only. Never store raw prompts, transcripts, audio, Plaid tokens, account numbers, or transaction descriptions.

## Regression Search Checklist

Run these scans before major UI/product commits:

```bash
rg -n "Rex app|Rex Backend|What Rex knows|What Rex Knows|Message Rex|Rex knows this|pending memory|memory candidate|MemoryCandidate|review session|candidate card|review before saving|Save this only after approval" apps/mobile/lib services/rex-api/app
```

```bash
rg -n "CSV-first|CSV first|upload CSV to get started|Upload CSV to get started|import CSV to get started|Import CSV to get started" apps/mobile/lib services/rex-api/app docs/clarity/product docs/clarity/plaid
```

```bash
rg -n "'[^']*Rex|\"[^\"]*Rex|pending|candidate|review" apps/mobile/lib services/rex-api/app/routes services/rex-api/app/models
```

Allowed exceptions should be explicitly reviewed, not ignored. Acceptable temporary exceptions include internal `rex_*` implementation filenames, historical migrations, archived docs, old-plan references, and service names that are scheduled for cleanup in later phases.

## Phase Handoff

Phase 2 defines the language contract only. Phase 3 should use this vocabulary to create a cleanup ledger and remove the highest-impact Rex-as-product labels from active code and docs.
