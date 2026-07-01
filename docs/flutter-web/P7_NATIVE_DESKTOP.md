# P7 — Native Desktop (Optional, Post-Launch)

**Previous:** [P6_PWA_DEPLOY.md](./P6_PWA_DEPLOY.md) (PWA stable in production)  
**Next:** none

## Objective

Optional macOS and Windows native apps — only if PWA does not meet distribution or OS integration needs.

## Prerequisites

- P6 complete and stable for 1–2 weeks
- Clear reason to ship native (see "When to skip" below)

## When to skip P7

Skip if installed PWA on desktop is sufficient for:

- Daily finance review
- Rex chat and voice
- Bank connect via web Plaid Link

Proceed only if you need:

- Mac App Store / Microsoft Store distribution
- Menu bar / system tray presence
- Offline beyond PWA cache
- OS-level mic/audio routing PWA cannot provide

## Tasks

### 1. Build verification

```bash
cd apps/mobile
flutter build macos --release
flutter build windows --release
```

Fix desktop-specific plugin gaps (same `AppCapabilities` pattern as web).

### 2. Plaid on desktop

Decision per platform:

- macOS/Windows: likely **web Plaid Link in embedded WebView** or same `WebPlaidLinkLauncher` pattern
- Do not assume native mobile Plaid SDK on desktop

### 3. Voice on desktop

Reuse P5 adapters:

- IO WebSocket likely works on desktop
- Mic via desktop `record` plugin
- No MethodChannel background voice unless implemented for desktop

### 4. Packaging

**macOS:**

- Code signing + notarization
- Bundle ID: `app.goclarity.clarity` (match iOS)

**Windows:**

- MSIX or traditional installer
- Package: `com.clarity.clarity` (match Android)

### 5. Distribution

- Direct download from `goclarity.app` OR store submission
- Auto-update strategy (separate from PWA)

## Exit criteria

- [ ] macOS app launches, login, core tabs work
- [ ] Windows app launches, login, core tabs work
- [ ] Same Supabase + rex-api config as web/mobile
- [ ] Signed/notarized (Mac) or signed installer (Windows)

## Files likely touched

- `apps/mobile/macos/`
- `apps/mobile/windows/`
- `apps/mobile/lib/core/platform/app_capabilities.dart` (desktop flags)
- Release scripts in `scripts/`

## Out of scope

- Linux desktop (unless explicitly requested)
- Separate desktop UI fork — reuse adaptive shell from P2
