# Archived UI Plan: Phase 3 Voice And Theme Lightening

Superseded by `docs/ui/CLARITY_UI_VISION.md`,
`docs/ui/CLARITY_UI_TOKENS.md`, and `docs/ui/CLARITY_UI_PHASES.md`.

## Original Status

Completed on 2026-06-24, with manual device voice QA still outstanding.

## Original Goal

Redesign the active Rex voice experience to feel modern, minimal, and closer to
ChatGPT/Grok voice UI patterns. Begin lightening the dark visual language
through softer cards, cleaner surfaces, and less dense borders.

## Completed Scope

- Replaced the text-heavy inline voice status box with a compact, icon-led
  panel.
- Kept listening/speaking as equalizer-style visuals and switched thinking to
  the Clarity diamond loader.
- Removed default helper/status sentences from the active voice panel while
  keeping failure messages and transcript text available.
- Replaced the `End Voice` text button with a compact end-call icon button.
- Preserved mute, retry, settings, failure, and end-call callbacks.
- Applied a conservative Rex-only surface lightening pass with softer panel
  fills and less dense borders.

## Historical Verification

- `dart format` completed for edited Dart files.
- `dart analyze` reported no issues.
- `flutter test test/assistant_navigation_test.dart` passed from `apps/mobile`
  with 6 passing tests.
- Runtime/manual voice QA still needed a device or simulator with microphone
  access.
