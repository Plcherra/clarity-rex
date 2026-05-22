# Import Progress Bottom Safe Area Plan

## Goal

Move import progress and persistent import error/success messaging away from the
top edge of the app so it works on iPhone devices with Dynamic Island, notches,
and status overlays.

The import state should remain visible, readable, and dismissible without
covering critical navigation or being hidden by system UI.

## Product Requirements

1. Progress must start immediately after CSV file selection.
2. Progress must stay continuous across parsing, saving, categorizing, applying
   categories, and refreshing.
3. Progress and error messages must respect safe areas on iPhone and desktop.
4. Errors must be persistent until dismissed.
5. The UI must not block the user from inspecting imported data after import
   completion.

## Phase 1: Move Active Progress To A Bottom Floating Panel

Priority: Critical

### Tasks

1. Replace the current top progress strip with a bottom floating panel.
2. Render the panel inside `SafeArea(top: false, bottom: true)`.
3. Position it above the bottom navigation bar.
4. Keep the existing import progress controller API unchanged.
5. Preserve current status text and percentage behavior.

### Key Files

1. `lib/features/shell/presentation/import_job_progress_banner.dart`
2. `lib/features/shell/presentation/home_shell.dart`

### Acceptance Criteria

1. The progress panel is fully visible on iPhone with Dynamic Island.
2. The panel does not overlap the tab bar.
3. The panel is readable on macOS, iPhone, and small screens.
4. Existing import progress tests still pass.

## Phase 2: Move Persistent Import Errors To Bottom Safe Area

Priority: Critical

### Tasks

1. Render persistent import failure messages in the same bottom-safe system.
2. Keep failures visible until the user dismisses them.
3. Use clear short copy, for example:
   `Imported 269 transactions. Some rows used fallback categories.`
4. Avoid full-width top red banners on mobile.

### Key Files

1. `lib/features/shell/presentation/import_job_progress_banner.dart`
2. `lib/features/transactions/application/import_job_status_service.dart`

### Acceptance Criteria

1. Error messages do not collide with the iPhone camera/status area.
2. The user can dismiss the message.
3. The message remains visible after navigation until dismissed.

## Phase 3: Improve Mobile Layout And Copy

Priority: High

### Tasks

1. Use compact labels on mobile:
   - `Importing...`
   - `Categorizing...`
   - `Saving categories...`
   - `Refreshing...`
2. Hide technical batch text from normal users.
3. Optionally show detailed batch text only in debug builds.
4. Use a compact linear progress bar and one short status line.

### Acceptance Criteria

1. No text wraps under the Dynamic Island.
2. No technical `1/3 batches` text appears in production UI.
3. Progress still feels continuous.

## Phase 4: Test Across Devices

Priority: High

### Tests

1. Run `flutter analyze`.
2. Run `flutter test`.
3. Manually test on:
   - iPhone with Dynamic Island
   - iPhone small screen
   - macOS desktop
4. Upload a CSV and confirm:
   - progress starts immediately
   - panel remains visible during account detail navigation
   - persistent failure/success message is readable

## Risks

1. A bottom overlay can cover bottom-page content if it is too tall.
2. A panel inside the shell body may need extra bottom padding on scrollable
   pages.
3. Error messages should not become easy to miss after moving away from the top.

