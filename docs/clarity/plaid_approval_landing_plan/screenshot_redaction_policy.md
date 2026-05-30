# Clarity Screenshot Redaction Policy

Status: File 03 Phase 2 screenshot policy approved for initial landing launch.

Purpose: prevent private user data, financial details, and unfinished product states from appearing in public Clarity landing assets.

## Screenshot Source Rules

Public screenshots must come from one of these approved sources:

- Synthetic demo account.
- Staged local/test account.
- Redacted screenshot where all private details have been removed and the asset still looks professional.

Avoid real personal account screenshots. If one is unavoidable, every sensitive value must be replaced, the source must be documented as redacted, and the asset must pass a second review before public use.

## Forbidden Visible Data

Screenshots must not show:

- Real names.
- Real email addresses.
- Real phone numbers.
- Real account numbers.
- Real routing numbers.
- Real card numbers.
- Real institution login screens.
- Real merchant history.
- Real transaction dates tied to a user.
- Real balances.
- Real income amounts.
- Real budget amounts.
- Real memory content.
- Raw internal labels such as `long_term_memory`, backend entity names, debug keys, or IDs.
- API keys, tokens, URLs with secrets, or environment values.

## Approved Demo Data Rules

Demo data should be:

- Plausible.
- Clearly synthetic.
- Visually representative of the product.
- Free of real user identifiers.
- Not copied from a real bank statement.

Recommended demo examples:

- Account name: `Everyday Checking`
- Merchant examples: `Neighborhood Market`, `City Coffee`, `Metro Transit`, `Streaming Service`
- Budget examples: `Groceries`, `Dining`, `Subscriptions`, `Transport`
- Rex prompt examples: `Review my spending this month` or `How is my grocery budget doing?`

Avoid:

- Real bank names unless brand/legal usage is reviewed.
- Real merchant names if they came from a personal statement.
- Personal medical, religious, political, or sensitive lifestyle signals.

## Screenshot Asset Register

Every screenshot considered for launch must be logged with:

| Field | Required |
| --- | --- |
| Asset filename | Yes |
| Feature shown | Yes |
| Source account type | Yes |
| Synthetic/staged/redacted status | Yes |
| Capture date | Yes |
| Reviewer | Yes |
| Approved for public use | Yes |
| Notes | Optional |

Recommended future file:

- `docs/clarity/plaid_approval_landing_plan/screenshot_asset_register.md`

Create that register when actual assets are selected.

## Redaction Checklist

Before committing a screenshot:

- Check every visible text label.
- Check every number.
- Check every merchant.
- Check every date.
- Check every account label.
- Check every memory/goal/chat message.
- Check status bars, notification banners, and dynamic island content.
- Check browser/device chrome if screenshots are taken from a real device.
- Check image metadata if the export workflow preserves location or device data.

## Visual Quality Requirements

Screenshots must be:

- Current enough to match the app users will see.
- Crisp on retina screens.
- Cropped intentionally.
- Free of accidental overlays, keyboard popups, notification banners, or personal wallpapers.
- Exported in optimized sizes for web.
- Given useful alt text in implementation.

## Review Workflow

Minimum screenshot review flow:

1. Capture from synthetic/staged/redacted source.
2. Add entry to screenshot asset register.
3. Run visual self-review against this policy.
4. Second-pass review before commit.
5. Final review before deployment.

If any private data is found, discard the asset and recapture from staged data.

## Plaid-Specific Restrictions

Do not show:

- Plaid Link UI.
- Bank login screens.
- Institution logos unless usage is reviewed.
- Any copy implying Plaid endorsement.
- Any screenshot that suggests the public landing page directly connects accounts.

## Acceptance Checklist

- Screenshots use synthetic, staged, or fully redacted data.
- No real names, balances, account numbers, emails, or merchant history are visible.
- Screenshot source date and test account/source type are documented.
- Every screenshot has a reviewer before public use.
- Assets do not expose unfinished features or raw internal labels.
