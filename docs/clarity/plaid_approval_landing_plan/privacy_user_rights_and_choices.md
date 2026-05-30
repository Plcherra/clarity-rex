# Clarity Privacy User Rights And Choices

Status: File 04 Phase 7 user rights and choices approved for initial landing launch draft.

## Purpose

This contract defines the user-facing privacy controls language for Clarity's public privacy policy. It is written to be jurisdiction-neutral, clear enough for Plaid review, and conservative enough to avoid promising operational capabilities that are not fully built.

## Draft Policy Section

### Your choices and privacy requests

Clarity is designed to give you control over the information you choose to connect or provide.

Depending on where you live, you may have rights to access, correct, delete, restrict, or object to certain uses of your personal information. You can contact us to make a privacy request, and we may need to verify your identity before completing the request.

You may be able to:

- Review the profile, account, transaction, budget, memory, chat, and assistant context information available in the product.
- Correct or update information where the product provides editing controls, such as categories, budgets, memory preferences, goals, and account details.
- Request deletion of your Clarity account or personal information, subject to security, legal, fraud-prevention, backup, and operational retention requirements.
- Disconnect a linked financial account. Disconnecting an account stops future access through that connection, but it may not automatically delete historical information already stored in Clarity unless you also request deletion.
- Manage Rex memory and assistant context where the product provides review, edit, deactivate, or delete controls.
- Control microphone access for voice features through your device settings. Voice features are user-initiated and require microphone permission.
- Opt out of marketing or waitlist communications if we send them. We may still send service, security, account, or privacy-related messages when needed.

To make a privacy request, contact us at `[privacy/support email]`.

For data deletion requests, you may also use the public data deletion page at `/data-deletion` once available.

## Required Page Links

The public site must include accessible links to:

- Privacy policy: `/privacy`
- Data deletion instructions: `/data-deletion`
- Support or contact page: `/contact`
- Terms of service: `/terms`

## Contact Requirements

Before launch, replace `[privacy/support email]` with the final monitored email address.

The email must be:

- Monitored by the project owner or support workflow.
- The same across privacy, terms, contact, security, and deletion pages unless there is a deliberate reason to separate them.
- Able to receive privacy, deletion, account disconnection, and support requests.

## Wording Rules

Allowed wording:

- "You may request..."
- "Depending on where you live..."
- "We may need to verify your identity..."
- "Subject to security, legal, fraud-prevention, backup, and operational retention requirements..."
- "Disconnecting stops future access through that connection..."

Avoid wording:

- "Instant deletion"
- "We delete all data immediately"
- "We delete all vendor copies"
- "We guarantee removal from every backup"
- "You have all rights under every privacy law"
- Exact legal response deadlines unless reviewed and operationally supported

## Feature-Specific Notes

### Linked Financial Accounts

The policy should make clear that users can disconnect linked financial accounts. The product should eventually expose this control directly, but the public launch copy may direct users to support if the control is not yet available in-app.

### Rex Memory

Memory controls must be described as user-reviewable and user-correctable only where the app supports it. Pending memory, approved memory, goals, and assistant context should never be described as invisible or impossible to change.

### Voice

Voice controls should reference device microphone settings and product-level voice controls. Do not imply Clarity records audio continuously. The privacy copy should stay aligned with implementation: voice is user-initiated and only active during voice interactions.

### Marketing

If the landing site collects waitlist emails, the privacy policy must include a simple opt-out statement. If no marketing emails are sent, this section can stay generic and conservative.

## Acceptance Checklist

- Covers access, correction, deletion, disconnection, support requests, microphone controls, memory controls, and marketing opt-out.
- Uses jurisdiction-neutral wording.
- Includes a contact email placeholder that must be replaced before launch.
- Links to `/data-deletion` as the public deletion path.
- Does not promise instant deletion or unsupported vendor/backups behavior.
- Keeps Clarity as the product name and Rex as the assistant inside the product.

