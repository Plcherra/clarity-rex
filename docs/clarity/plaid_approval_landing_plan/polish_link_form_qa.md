# Link And Form QA

Status: File 09 Phase 6 link and form QA complete.

## Scope

This pass verifies that public routes, compliance cross-links, support paths, and form wiring are coherent before launch.

## Routes Checked

Generated HTML was checked for:

- `/`
- `/privacy`
- `/terms`
- `/security`
- `/data-deletion`
- `/contact`
- `/form-success`
- `/form-error`

## Link Checks

Checked link categories:

- Header navigation.
- Footer navigation.
- Legal and compliance cross-links.
- Data deletion links.
- Contact links.
- Support email `mailto:` links.
- Generated CSS asset link.
- Canonical public `https://rexpilot.com` links.

Result: no unknown local links were found.

## Form Checks

Checked form behavior contract:

- Waitlist form posts to `https://formsubmit.co/clarity.rex@gmail.com`.
- Contact form posts to `https://formsubmit.co/clarity.rex@gmail.com`.
- Forms redirect to `https://rexpilot.com/form-success` after accepted submission.
- Required name and email fields exist.
- Contact reason selector exists.
- Consent checkbox exists.
- Honeypot field exists.
- Sensitive-data warning exists near both forms.
- Failure fallback page exists at `/form-error`.
- Users can also contact `clarity.rex@gmail.com` if the form fails.

Real form submission was intentionally not performed in this QA pass to avoid sending test messages to the monitored public support inbox.

## Known Limitations

FormSubmit controls final external delivery behavior and initial email-confirmation setup. Before launch, confirm the FormSubmit destination has been activated for `clarity.rex@gmail.com`.

## Verification Commands

- `./scripts/web_release_build.sh`
- Generated HTML route/link scan.
- Generated HTML form-contract scan.

## Acceptance Decision

File 09 Phase 6 passes. The site is ready for File 09 Phase 7 copy consistency pass.
