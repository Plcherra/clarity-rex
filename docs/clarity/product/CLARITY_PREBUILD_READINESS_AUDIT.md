# Clarity Prebuild Readiness Audit

## Executive Summary

Status: Ready to start subsystem execution.

The prebuild foundation now has enough shared contracts to begin implementation without foundational ambiguity. Clarity is defined as one app, Rex is constrained to Assistant personality/conversation use, Plaid is primary with CSV as fallback, usage tracking is safe and server-first, design tokens are app-wide, shared read models define truth parity, and multi-user data boundaries are explicit.

The next executable plan is:

1. `docs/clarity/product/CLARITY_USAGE_TRACKING_SIMPLIFIED_PLAN.md`
2. Phase 1 - Usage Event Schema And RLS

## Foundation Documents

| Document | Status | Notes |
| --- | --- | --- |
| `CLARITY_ARCHITECTURE_SNAPSHOT.md` | Ready | Current mobile, backend, Supabase, CSV, Assistant, Plaid, and usage state mapped. |
| `CLARITY_PRODUCT_VOCABULARY.md` | Ready | One-app language rules are defined. |
| `CLARITY_REX_LABEL_CLEANUP_LEDGER.md` | Ready | Rex-as-product cleanup is tracked and allowed exceptions are documented. |
| `CLARITY_SHARED_READ_MODELS.md` | Ready | Screens and Assistant must use the same Clarity models. |
| `CLARITY_DESIGN_TOKEN_CONTRACT.md` | Ready | App-wide dark/minimal token direction is defined. |
| `CLARITY_MULTI_USER_DATA_BOUNDARY.md` | Ready | User-owned data, service-role writes, Plaid, usage, Assistant, and cross-user tests are scoped. |
| `CLARITY_EXECUTION_GATES.md` | Ready | Backend, Flutter, screenshot, privacy, RLS, Assistant truth, and line-count gates are defined. |
| `FILE_SIZE_EXCEPTION_LEDGER.md` | Ready | Current oversized files are assigned to subsystem cleanup owners. |

## Current Plan Structure

| Order | Plan | Status | Readiness |
| ---: | --- | --- | --- |
| 0 | `CLARITY_PREBUILD_FOUNDATION_MASTER_PLAN.md` | Ready | Completes with this audit. |
| 1 | `CLARITY_USAGE_TRACKING_SIMPLIFIED_PLAN.md` | Ready | First implementation plan; safe event schema and RLS come before telemetry capture. |
| 2 | `PLAID_BACKEND_CORE_MASTER_PLAN.md` | Ready | Backend-owned secret/token/sync foundation is phased. |
| 3 | `PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md` | Ready | Native Link and CSV fallback are separated from backend core. |
| 4 | `CLARITY_DESIGN_SYSTEM_MASTER_PLAN.md` | Ready | Starts with color audit before global theme changes. |
| 5 | `CLARITY_UNIFIED_PRODUCT_SHELL_MASTER_PLAN.md` | Ready | Product shell work follows design-token direction. |
| 6 | `CLARITY_FINANCIAL_EXPERIENCE_MASTER_PLAN.md` | Ready | Dashboard/accounts/transactions/budgets are tied to Plaid and read-model contracts. |
| 7 | `CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md` | Ready | Voice, memory corrections, shared context, and truth tests are owned. |
| 8 | `CLARITY_RELEASE_VALIDATION_MASTER_PLAN.md` | Ready | Final gate only; subsystem hardening stays in subsystem plans. |

## Old Broad Plan Status

| Old plan | Status |
| --- | --- |
| `docs/FULL_PROJECT_11_10_POLISH_MASTER_PLAN.md` | Marked superseded; retained as history. |
| `docs/NEW_REX_SIMPLIFIED_ARCHITECTURE.md` | Marked superseded; retained as Rex simplification history. |
| `docs/REX_VOICE_MEMORY_SPEED_OPTIMIZATION_MASTER_PLAN.md` | Marked superseded; retained as voice/memory history. |
| `docs/REX_UI_DARK_MINIMAL_POLISH_MASTER_PLAN.md` | Marked superseded; retained as Assistant UI history. |

Older nested docs may still mention legacy memory candidates or Rex-specific polish work as historical audit material. Active product code must stay clean, and current work must use the nine subsystem plans above.

## Subsystem Readiness

| Subsystem | Ready? | Remaining unknowns | Owner |
| --- | --- | --- | --- |
| Usage tracking | Yes | Admin/internal query shape and rollup details | Usage Tracking phases 6-7 |
| Plaid backend | Yes | Exact Plaid webhook event coverage and sync edge cases | Plaid Backend phases 8-10 |
| Plaid mobile | Yes | Native SDK integration details; Hosted Link fallback only if blocked | Plaid Mobile phases 2 and 9 |
| Product shell | Yes | Final bottom-nav labels after UI/product pass | Unified Product Shell phases 1-2 |
| Design system | Yes | Exact extracted logo palette values | Design System phases 1-3 |
| Financial experience | Yes | Final dashboard hierarchy and Plaid/CSV dedupe presentation | Financial Experience phases 1-9 |
| Assistant intelligence | Yes | Voice latency target tuning and final truth tests | Assistant Intelligence phases 1-9 |
| Release validation | Yes | Final device checklist outcomes | Release Validation phase 8 |

## Owned Critical Gaps

| Gap | Owner plan |
| --- | --- |
| Per-user usage/cost/latency visibility | `CLARITY_USAGE_TRACKING_SIMPLIFIED_PLAN.md` |
| Plaid secret handling and token exchange | `PLAID_BACKEND_CORE_MASTER_PLAN.md` |
| Plaid native Link and connected account UI | `PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md` |
| CSV demotion from primary path to fallback | `PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md`, `CLARITY_FINANCIAL_EXPERIENCE_MASTER_PLAN.md` |
| Modern app-wide dark/minimal UI | `CLARITY_DESIGN_SYSTEM_MASTER_PLAN.md` |
| Clarity/Rex product identity cleanup | `CLARITY_UNIFIED_PRODUCT_SHELL_MASTER_PLAN.md` |
| Assistant saying it does not know data shown in Clarity | `CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md` |
| Voice and chat context divergence | `CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md` |
| Oversized active source files | `FILE_SIZE_EXCEPTION_LEDGER.md` and assigned subsystem plans |
| RLS and cross-user isolation | `CLARITY_MULTI_USER_DATA_BOUNDARY.md`, `CLARITY_RELEASE_VALIDATION_MASTER_PLAN.md` |

## Active Code Search Result

Active product paths were checked for the old high-risk terms:

```bash
rg -n "Rex app|pending memory|memory candidate|review session|CSV-first|csv-first|MemoryCandidate|memory_candidate|memory-candidates" apps/mobile/lib services/rex-api/app
```

Result: no matches in active product code.

## Readiness Decision

The project is ready to leave prebuild foundation and begin subsystem implementation.

Next step: start `CLARITY_USAGE_TRACKING_SIMPLIFIED_PLAN.md`, Phase 1 - Usage Event Schema And RLS.

