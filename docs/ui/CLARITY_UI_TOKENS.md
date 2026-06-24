# Clarity UI Tokens

## Token Rule

All product colors should flow through `apps/mobile/lib/theme`. Feature and Rex
widgets should read colors from `Theme.of(context)`, `ColorScheme`, or the
Clarity theme extension. Hard-coded bright blue values should not appear in
screen code.

## Dark Theme

- Background: near-black, `#0A0A0A`
- Surface: soft graphite, `#151515`
- Elevated surface: `#1D1D1D`
- Soft surface: `#242424`
- Accent: soft teal/cyan, `#00E5C0`
- Text primary: `#F4F4F4`
- Text secondary: `#A7A7A7`
- Text muted: `#777777`
- Border/divider: neutral gray with low opacity
- Success/positive finance: calm green
- Danger/negative finance: soft red

## Light Theme

- Background: off-white, `#F8F9FA`
- Surface: white, `#FFFFFF`
- Elevated surface: `#F1F3F5`
- Soft surface: `#E9ECEF`
- Accent: restrained teal, `#00BFA5`
- Text primary: `#111111`
- Text secondary: `#555555`
- Text muted: `#767676`
- Border/divider: subtle cool gray
- Success/positive finance: readable green
- Danger/negative finance: readable red

## Component Defaults

- Cards: flat by default, no gradient edge.
- Borders: neutral and opt-in.
- Shadows: minimal; avoid glow except for rare focused states.
- Filled buttons: teal only for primary calls to action.
- Secondary buttons: ghost, text, or outline.
- Chips: low-fill, compact, no heavy stroke.
- Inputs: calm outline or filled surface; no blue focus ring.
- Navigation: selected state uses accent sparingly with a soft indicator.

## Rex Tokens

`RexUiTokens` should not define a second color system. It may keep spacing and
radius aliases, but Rex surfaces must share the Clarity theme tokens so chat,
voice, memory, and finance feel like one app.

## Finance Semantics

The finance palette is separate from the brand accent:

- Positive balance/income: finance positive.
- Negative balance/spending/over budget: finance negative.
- Warning/pressure: warning or danger based on severity.
- Category pills: neutral surface with muted text unless selected.
