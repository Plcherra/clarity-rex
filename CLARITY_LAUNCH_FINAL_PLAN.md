# Clarity Launch Final Plan (June 2026)

## Must-Have Before Launch (4 items)
1. Voice experience (natural flow while walking)
2. Reliable Delete
3. Basic Memory + Recall
4. No catastrophic errors

## Current Status
Clarity is close enough to focus on launch hardening, not new systems. Rex chat and voice share the same backend brain path, memory and recall are being simplified for reliability, and the main risk is inconsistent behavior around voice, delete, recall, and error handling. Launch should prioritize trust: Rex should find old chat mentions broadly, clearly label chat history versus saved memory, delete only with backend confirmation, and never claim success when an action failed.

## Next Actions (in order)
1. Verify voice walking flow end-to-end in `lib/rex/voice`, `lib/rex/chat`, and `services/rex-api/app/services/chat_service.py`.
2. Harden Reliable Delete in `services/rex-api/app/services/memory_turn_service.py`, `services/rex-api/app/services/memory_turn_direct_helpers.py`, and the Knows UI delete path under `lib/rex`.
3. Finish Basic Memory + Recall checks in `services/rex-api/app/services/chat_recall_service.py`, `services/rex-api/app/services/chat_search_ranking.py`, and `services/rex-api/app/services/rex_intent_router.py`.
4. Run launch smoke tests for chat, voice, memory save, memory delete, recall, and financial no-guessing in `services/rex-api/tests` plus the core Flutter Rex screens.
5. Fix only launch-blocking crashes, false success messages, and broken recall/delete paths before June 25-26.
