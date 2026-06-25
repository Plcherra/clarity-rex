# Product Wiring Completion Plan

## Goal

Make every implemented product surface either reachable and connected or intentionally removed.

## Current Gaps

- Standalone `UploadScreen` was removed; current CSV flows use account-scoped import screens instead.
- `TransactionReviewScreen` is now reachable from the Dashboard app bar.
- Goals tab now supports create, complete, miss, and archive flows through Rex API.
- Goals still lack edit-after-create and actionable accountability signals in MVP.
- Backend has routes that mobile does not use yet: memory corrections, entity events, plan milestones, accountability drill-downs, and usage routes.
- Some features are split between direct Supabase and Rex API without clear user-facing boundaries.

## Status

**MVP code/static complete** for route wiring and orphan cleanup. Manual navigation smoke and backend-only route UI decisions remain for Plan 8.

## Work Plan

### 1. Decide Orphan Screen Fate

- Completed: `UploadScreen` was deleted because account-scoped CSV import is the intended product flow.
- Completed: `TransactionReviewScreen` was kept and wired into the Dashboard app bar for global and account scopes.

### 2. Build A Feature Route Map

- Document every main route/screen in one route map.
- Include:
  - Entry point.
  - Required controller/service.
  - Backend or Supabase dependency.
  - Empty/degraded state.

### 3. Align UI With Backend Capabilities

- For every backend route, classify it as:
  - User-facing now.
  - Backend-only by design.
  - Future feature.
  - Dead/legacy.
- Move dead/legacy items out of production-facing docs.

### 4. Add Missing User Feedback

- If a backend feature is not configured, the UI should say what is unavailable.
- Rex API unavailable should produce Assistant-specific messaging.
- Supabase unavailable should produce app-level auth/data messaging.
- Plaid unavailable should produce bank-connection messaging.

### 5. Refresh Docs

- Update `docs/PROJECT_MAP.md` after wiring decisions.
- Update `docs/project-structure.md` to remove stale `lib/services` references.
- Add the final route map to the docs or keep it inside `PROJECT_MAP.md`.
- Completed: `docs/PROJECT_ROUTE_MAP.md` now tracks screen wiring, data sources, and route classification.

## Acceptance Criteria

- No implemented screen is unreachable unless intentionally marked experimental or removed.
- Every visible feature has a clear data source.
- Every backend route is classified.
- App docs match the actual navigation and production paths.
- `flutter analyze` passes.

## Suggested Verification

- Manual navigation smoke through every main tab and pushed/modal surface.
- Search for each screen class name and confirm there is a route or a documented removal.
- Search mobile API clients and backend routes to confirm known intentional backend-only routes are documented.
