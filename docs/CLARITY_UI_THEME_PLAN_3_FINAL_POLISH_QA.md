# Clarity UI Theme Plan 3: Voice Experience Redesign And Theme Lightening

## Status

| Item | State |
|------|-------|
| Minimal ChatGPT/Grok-style voice panel | Complete |
| Icon-led listening / thinking / speaking states | Complete |
| Remove heavy voice status/helper text | Complete |
| Replace `End Voice` text button with compact icon button | Complete |
| Initial theme-lightening pass | Complete |
| Manual voice QA | Needs device QA |

**Last updated:** 2026-06-24  
**Source:** `cursor_chat_app_logo_and_splash_screen.json`

## Branding Note

Splash screen and launcher icon branding were completed separately. They are not the completion criteria for this plan.

Current completed branding work:

- `ClaritySplashScreen` uses full-screen `assets/brand/clarity_splash_screen.png`.
- `assets/brand/clarity_app_icon.png` is the white-background launcher icon source.
- iOS and Android launcher icon assets were generated from that source.

## Goal

Redesign the active Rex voice experience so it feels modern, minimal, and closer to ChatGPT/Grok voice UI patterns. Use this pass to begin lightening the app’s dark visual language through softer cards, cleaner surfaces, and less dense borders.

## Checklist

- [x] Replace the current voice status box with a minimal voice panel.
- [x] Use compact icon-led state display where possible.
- [x] Listening state uses a wave/equalizer-style icon.
- [x] Thinking state uses the animated diamond loader.
- [x] Speaking state uses a subtle audio/equalizer indicator.
- [x] Remove heavy labels like `Listening to you...`, `Rex is thinking...`, and `Rex is speaking`.
- [x] Remove heavy helper text like `Ready. Keep the phone in your pocket and talk naturally.`
- [x] Replace `End Voice` text button with a compact end-call icon button.
- [x] Preserve mic mute, retry, settings, failure, and end-call behavior.
- [x] Start a careful theme-lightening pass: less dense borders, softer cards, cleaner dark surfaces.
- [x] Note future light/dark theme support separately if needed.

## Target Areas

Likely files to inspect and update:

- `apps/mobile/lib/rex/chat/presentation/widgets/inline_voice_call_panel.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/voice/domain/voice_call_state.dart`
- `apps/mobile/lib/widgets/clarity_diamond_loader.dart`
- `apps/mobile/lib/widgets/clarity_path_loader.dart`
- `apps/mobile/lib/rex/presentation/rex_ui_tokens.dart`
- `apps/mobile/lib/theme/clarity_theme.dart`
- `apps/mobile/lib/theme/clarity_colors.dart`

## Current Issues To Fix

The current inline voice panel still has a text-heavy default UI:

- `Listening to you...`
- `Listening - you can speak`
- `Rex is thinking...`
- `Rex is speaking`
- `Ready. Keep the phone in your pocket and talk naturally.`
- `Rex is replying. End Voice if you need to stop.`
- `End Voice` text button

These should be replaced by a calmer, compact, icon-led interaction surface.

## Requested Voice Direction

- Keep the existing phase icons where they work.
- Listening can keep the wave/equalizer visual.
- Thinking should use the Clarity diamond loader.
- Speaking should use a subtle equalizer/audio animation.
- Do not show descriptive phase sentences by default.
- Keep transcript display available, but make the transcription panel feel modern and minimal.
- End voice should be a compact icon button, not a text-heavy button.

## Theme-Lightening Direction

This is not a full light theme. It is an initial dark-theme refinement:

- Softer cards.
- Cleaner dark surfaces.
- Less dense borders.
- Less heavy panel outlines.
- Better contrast without making the app bright.

Any future full light/dark theme support should be planned separately.

## Constraints

- Do not change voice capture, streaming, transcription, playback, or backend behavior.
- Do not change Rex Brain, memory, recall, or prompt behavior.
- Do not remove retry/settings/mute/end-call functionality.
- Do not add topic-specific Rex behavior.
- Keep Rex UI changes under `apps/mobile/lib/rex`.
- Keep shared visual-token changes conservative and centralized.

## Expected Visual Outcome

- Voice mode feels more like a modern assistant call surface.
- Phase state is readable without heavy explanatory text.
- The transcript area feels intentional, not like a default status box.
- The end-call control is compact and visually obvious.
- The surrounding dark theme feels slightly lighter, cleaner, and less bordered.

## Verification

Run from `apps/mobile`:

```bash
flutter analyze
flutter test test/assistant_navigation_test.dart
```

Manual checks:

- Start voice mode.
- Listening state.
- Thinking state.
- Speaking state.
- Muted state.
- Failure/retry/settings state.
- End-call icon behavior.
- Chat input bar while voice is active.
- Visual fit on common iPhone widths.

## Manual Device QA Script

Run on a simulator or device with microphone access:

1. Open Assistant > Chat and tap the mic button.
2. Confirm the voice panel appears as a compact icon-led surface with no default status sentence.
3. While listening, confirm the equalizer/wave icon animates and the mic mute button remains available.
4. Mute and unmute the mic; confirm the compact `Muted` chip appears only while muted.
5. Speak a short message; confirm transcript text appears in the small transcript surface when available.
6. Wait for Rex to process; confirm the thinking state uses the Clarity diamond loader.
7. Let Rex reply; confirm speaking uses the subtle equalizer/audio indicator.
8. Tap the compact end-call icon; confirm voice mode exits and the chat input returns to normal.
9. Deny or revoke microphone permission, then start voice; confirm Settings and Try again controls still appear.
10. Check the panel at common iPhone widths for overflow or clipped controls.

## Completion Report

Implemented:

- Replaced the text-heavy inline voice status box with a compact, icon-led panel.
- Kept listening/speaking as equalizer-style visuals and switched thinking to the Clarity diamond loader.
- Removed default helper/status sentences from the active voice panel while keeping failure messages and transcript text available.
- Replaced the `End Voice` text button with a compact end-call icon button.
- Preserved mute, retry, settings, failure, and end-call callbacks.
- Applied a conservative Rex-only surface lightening pass with softer panel fills and less dense borders.

Verification:

- `dart format` completed for edited Dart files.
- `dart analyze` reported no issues.
- `flutter test test/assistant_navigation_test.dart` passed from `apps/mobile` with 6 passing tests.
- Runtime/manual voice QA still needs to be checked on a device or simulator with microphone access.
