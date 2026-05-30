# Plaid Approval Landing Master Plan

## Executive Summary

Clarity needs a public, professional web presence before requesting broader Plaid access. The immediate goal is not a full web app. The goal is a credible landing site that explains Clarity, Rex, data access, user consent, privacy, security, terms, support, and account/data deletion in language that is understandable to users and reviewable by Plaid.

Product naming rule: the product is **Clarity**. **Rex** is the AI assistant inside Clarity.

## Overall Strategy & Why This Order

Build the public trust surface first:

1. Landing page
2. Privacy Policy
3. Terms of Service
4. Security and data handling page
5. Waitlist/contact flow
6. Technical deployment and SEO

This order is faster and lower-risk than building a full web app. Plaid approval depends heavily on clear business purpose, user consent, data use, data retention, security posture, and user support. A full browser version can come later after the public compliance surface is live.

## Risks & Dependencies

- Risk: unclear Plaid-facing data language causes review friction.
  - Mitigation: explicitly explain what data is requested, why, how it is used, how it is protected, and how users can disconnect/delete it.
- Risk: legal pages read like placeholders.
  - Mitigation: write product-specific drafts and flag final attorney review before production.
- Risk: overbuilding a web app delays Plaid request.
  - Mitigation: keep initial scope to public pages, waitlist/contact, and optional demo screenshots.
- Risk: screenshots expose personal financial data.
  - Mitigation: use redacted, synthetic, or carefully staged screenshots only.
- Risk: public contact/waitlist creates spam or privacy obligations.
  - Mitigation: collect minimal information and include consent copy.

## Global Definition Of Done

- Public site is live on the intended domain.
- Product name, support email, company/operator name, and contact path are visible.
- Landing page clearly explains Clarity and Rex without claiming bank partnership or guaranteed financial outcomes.
- Privacy Policy, Terms of Service, Security/Data Handling, Data Deletion, and Contact pages are linked from the footer.
- Plaid consent language explains account connection, transaction/balance data use, retention, deletion, and disconnection.
- Mobile and desktop layouts are clean, accessible, and fast.
- No personal financial data appears in public screenshots.
- Forms collect only necessary data and include anti-spam protection.
- Metadata, Open Graph, favicon, sitemap, and robots.txt are configured.
- Final review confirms there are no raw internal labels, test copy, broken links, or placeholder legal sections.

## Plan Files

- `01_landing_page_structure.md` - public site architecture, routes, footer, information hierarchy.
- `02_hero_value_proposition.md` - above-the-fold message, trust promise, primary calls to action.
- `03_features_screenshots.md` - feature sections, screenshot policy, product proof, redaction rules.
- `04_privacy_policy.md` - privacy draft structure and Plaid data language.
- `05_terms_of_service.md` - user obligations, disclaimers, financial advice boundaries, account rules.
- `06_security_and_data_handling.md` - security posture, data lifecycle, vendor disclosure, deletion flow.
- `07_waitlist_and_contact.md` - waitlist, support/contact, data deletion intake, spam protection.
- `08_technical_implementation.md` - recommended stack, routing, hosting, analytics, env management.
- `09_polish_testing_seo.md` - mobile polish, accessibility, SEO, link checks, performance.
- `10_final_review_deployment.md` - Plaid review package, deployment checklist, final release gate.

## Recommended Execution Order

1. `01_landing_page_structure.md`
2. `02_hero_value_proposition.md`
3. `03_features_screenshots.md`
4. `04_privacy_policy.md`
5. `05_terms_of_service.md`
6. `06_security_and_data_handling.md`
7. `07_waitlist_and_contact.md`
8. `08_technical_implementation.md`
9. `09_polish_testing_seo.md`
10. `10_final_review_deployment.md`

Current Cursor: `03_features_screenshots.md` Phase 5 complete. Next implementation step: `03_features_screenshots.md` Phase 6.

Full Plan Complete: Yes.
