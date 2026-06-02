# Universal Code Architecture Standards

Purpose: define a timeless, project-agnostic architecture standard for building high-quality software across Clarity, EchoDesk, FlowForce, and future products.

This document is designed for solo founders and small teams who need professional-grade systems without unnecessary process weight. The goal is simple: keep code easy to understand, safe to change, and durable under product pressure.

## 1. Core Principles

### Quality-First Philosophy

High-quality code is not code with the most abstractions. High-quality code is code that remains understandable and useful as the product changes.

Every project should optimize for:

| Principle | Meaning | Practical Rule |
| --- | --- | --- |
| Clarity over cleverness | Future-you should understand the code quickly. | Prefer obvious names, explicit flow, and boring patterns. |
| Small units, clear responsibility | A file or class should have one main reason to change. | Split when responsibilities drift. |
| Stable boundaries | Business rules should not be tangled with UI, network, or storage details. | Keep domain logic independent where practical. |
| Testable behavior | Important behavior should be verifiable without full manual testing. | Add tests around decisions, transformations, and risky workflows. |
| Incremental architecture | Add structure when it protects velocity, not to impress anyone. | Avoid premature frameworks and speculative abstractions. |
| Honest tradeoffs | Technical debt is acceptable only when visible and contained. | Document shortcuts and set a cleanup trigger. |

### Engineering Values

- Simplicity is a feature.
- Maintainability is speed preserved over time.
- Duplication is cheaper than the wrong abstraction, until the pattern becomes clear.
- Silent failures are unacceptable in user-critical flows.
- Every major feature should be understandable from its module contract.
- Refactoring is not optional cleanup; it is part of feature delivery when complexity crosses agreed limits.

## 2. File & Module Size Limits

Size limits are not vanity metrics. They are guardrails against files becoming too large to reason about safely.

### Default Limits

| Artifact | Target | Hard Limit | Action When Exceeded |
| --- | ---: | ---: | --- |
| Source file | 150-300 lines | 500 lines | Split before adding new behavior. |
| Test file | 200-400 lines | 500 lines | Split by behavior suite. |
| UI component/page | 150-300 lines | 500 lines | Extract widgets/components, state, API calls. |
| Service/class | 100-250 lines | 400 lines | Extract policy, repository, formatter, parser, or coordinator. |
| Function/method | 5-40 lines | 80 lines | Extract named sub-steps or reduce branching. |
| Module folder | 5-12 focused files | Review at 20 files | Add subfolders by responsibility. |

### Responsibility Rules

A file should usually own one of these responsibilities:

- Orchestration
- Domain rule or policy
- Data access
- API/client integration
- Parsing or formatting
- UI rendering
- UI state management
- Validation
- Test fixtures
- Behavior tests

If a file owns more than two of these, it is probably becoming a god-file.

### Exceptions Process

A file may exceed the hard limit only if all are true:

1. It is generated code, framework-required glue, or a stable data model.
2. Splitting it would make the system harder to understand.
3. The exception is documented in the module contract.
4. A future cleanup trigger is defined.

## 3. Layered Architecture

Use a layered structure that separates business meaning from delivery mechanisms.

### Recommended Layers

```text
feature/
  domain/
    models/
    policies/
    value_objects/
  application/
    controllers/
    services/
    use_cases/
  data/
    api/
    repositories/
    mappers/
  presentation/
    pages/
    widgets/
    view_models/
  tests/
```

Not every feature needs every layer. Small features can start lean, but boundaries should remain clear.

### Layer Responsibilities

| Layer | Owns | Should Not Own |
| --- | --- | --- |
| Domain | Business concepts, rules, decisions, invariants | HTTP, database clients, UI framework details |
| Application | Use cases, orchestration, workflow coordination | Raw SQL details, widget rendering |
| Data | External APIs, persistence, DTO mapping | Business decisions |
| Presentation | Screens, components, visual state | Durable business rules |
| Tests | Behavior verification and fixtures | Production-only shortcuts |

### Dependency Direction

Prefer dependencies flowing inward:

```text
presentation -> application -> domain
data --------^
```

The domain layer should be the least dependent and most reusable layer.

## 4. Naming & Organization Conventions

### Naming Principles

- Names should explain purpose, not implementation trivia.
- Use domain language the user or product understands.
- Avoid vague names such as `manager`, `helper`, `utils`, `misc`, `common`, unless the scope is very narrow and documented.
- Prefer explicit role names: `MemoryCandidateWriter`, `InvoicePolicy`, `SubscriptionRepository`, `ChatResponseFormatter`.

### File Naming

| Type | Pattern | Example |
| --- | --- | --- |
| Domain policy | `<concept>_policy` | `subscription_policy.py` |
| Repository | `<entity>_repository` | `memory_repository.dart` |
| API client | `<service>_api` | `plaid_api_client.ts` |
| Formatter | `<thing>_formatter` | `chat_response_formatter.py` |
| Parser | `<thing>_parser` | `invoice_parser.py` |
| Controller | `<feature>_controller` | `memory_controller.dart` |
| Test suite | `test_<behavior>` | `test_memory_recall.py` |

### Folder Rules

- Organize by feature first, technical layer second.
- Keep shared code truly shared. Do not create global dumping grounds.
- If a shared module starts depending on one feature’s domain language, move it into that feature.

## 5. Forbidden Anti-Patterns

These patterns are not allowed unless explicitly documented as temporary debt.

| Anti-Pattern | Why It Hurts | Better Approach |
| --- | --- | --- |
| God-file | Impossible to reason about safely. | Split by responsibility. |
| God-service | Business rules, API calls, formatting, and storage all tangled. | Use orchestrator plus focused services. |
| Hidden state markers | Fragile, invisible contracts between systems. | Use explicit records or typed metadata. |
| Silent failure | User thinks something worked when it did not. | Return clear errors and log privacy-safe diagnostics. |
| Stringly typed business logic | Typos become runtime bugs. | Use enums, constants, typed models, or schemas. |
| UI-owned business rules | Rules become duplicated and inconsistent. | Move durable decisions into domain/application layer. |
| Catch-all utilities | Turns into a junk drawer. | Create focused modules with explicit names. |
| Premature abstraction | Adds ceremony before the pattern is proven. | Duplicate once, abstract when the third case appears or risk is clear. |
| Circular dependencies | Makes changes unpredictable. | Invert dependency or extract shared domain model. |
| Over-mocked tests | Tests implementation details instead of behavior. | Test public behavior and important boundaries. |

### Bad Example

```text
chat_service.py
  - calls AI model
  - formats UI cards
  - writes database records
  - parses memory corrections
  - handles billing rules
  - sends email
  - contains 2,000 lines
```

### Better Example

```text
chat_service.py                    # coordinates the turn
memory_intent_service.py            # detects simple memory intent
memory_confirmation_repository.py   # stores confirmation records
memory_candidate_writer.py          # writes review candidates
chat_response_formatter.py          # formats response metadata
billing_access_policy.py            # decides access
```

## 6. Mandatory Documentation Per Module/Feature

Every significant feature should include a module contract before or during implementation.

Minimum documentation:

| Document | Required When | Purpose |
| --- | --- | --- |
| Module contract | Any feature with backend, state, or external API behavior | Defines scope, boundaries, data flow, failure states |
| Master plan | Multi-phase work or refactor | Keeps execution sequential and testable |
| Architecture Decision Record | Major irreversible or costly decision | Records why a path was chosen |
| Manual QA checklist | User-facing workflow | Makes release testing repeatable |

### Module Contract Must Answer

- What problem does this module solve?
- What does it explicitly not solve?
- What are the public entry points?
- What data does it read/write?
- What failure states exist?
- What tests protect it?
- What files are allowed to change for normal feature work?

## 7. Refactoring Triggers

Refactoring must begin when any trigger is hit.

### Automatic Triggers

| Trigger | Required Response |
| --- | --- |
| File exceeds 500 lines | Split before adding new behavior. |
| Function exceeds 80 lines | Extract sub-steps or simplify flow. |
| More than 3 responsibilities in one file | Split by responsibility. |
| Same logic copied 3 times | Extract shared policy/helper. |
| Test requires excessive setup | Extract fixture or simplify dependency boundary. |
| Bug fix touches 4+ unrelated areas | Revisit module boundaries. |
| New feature requires editing a god-file | Refactor first or create a narrow adapter. |
| User-facing workflow has silent failure | Add explicit state, error handling, and logs. |

### Refactor Safely

1. Write or identify behavior tests first.
2. Move code without changing behavior.
3. Keep public APIs stable where possible.
4. Run focused tests after each extraction.
5. Record before/after line counts.
6. Document what moved and where.
7. Only then add new behavior.

## 8. Testing & Verification Standards

Testing should protect behavior, not freeze implementation details.

### Test Pyramid

| Test Type | Purpose | Frequency |
| --- | --- | --- |
| Unit tests | Validate pure rules, parsing, formatting, policies | Many |
| Service/use-case tests | Validate workflow behavior | Common |
| Integration tests | Validate API/database/external boundary | Focused |
| UI/widget tests | Validate important states and rendering | Focused |
| Manual smoke tests | Validate real device and real workflow feel | Before release |

### Required Tests For High-Risk Features

Add tests when code touches:

- Authentication
- Payments/subscriptions
- Financial data
- Memory/personalization
- AI-generated actions
- Data deletion/privacy
- External APIs
- Background jobs
- Mobile navigation or release-critical UI

### Verification Standard

Every completed phase should include:

- Commands run
- Tests passed or skipped
- Manual checks required
- Known residual risk

If a test cannot be run, say why and define the next verification step.

## 9. Code Review Checklist

Use this checklist even when reviewing your own code.

### Architecture

- Does each changed file have one clear responsibility?
- Did any file cross the line-count limit?
- Are domain rules separated from UI/API/storage details?
- Are module boundaries clearer than before?

### Behavior

- Does the code handle success, failure, empty, loading, and retry states?
- Are user-facing errors understandable?
- Are important decisions explicit rather than hidden in strings or side effects?
- Could this silently fail?

### Maintainability

- Are names clear and specific?
- Is the abstraction justified by real complexity?
- Is duplicated logic intentional or ready to extract?
- Are comments useful rather than decorative?

### Testing

- Do tests cover the user story, not just implementation?
- Is there a regression test for the bug or risky behavior?
- Did focused tests pass?
- Is manual QA documented when needed?

### Security & Privacy

- Are secrets kept out of code and logs?
- Are logs privacy-safe?
- Is sensitive user data minimized?
- Are deletion and retention expectations respected?

## 10. How To Start A New Feature

Use this flow for every meaningful feature.

### Step 1: Define The Feature Boundary

Write a short module contract:

- Problem
- Users affected
- In scope
- Out of scope
- Data touched
- Failure states

### Step 2: Identify The Layer

Decide where the feature belongs:

- UI-only
- Application workflow
- Domain rule
- Data/API integration
- Cross-cutting infrastructure

### Step 3: Choose The Smallest Useful Architecture

Start with the fewest files that preserve boundaries. Do not create empty layers.

Good starting point:

```text
feature/
  application/<feature>_service
  data/<feature>_repository
  presentation/<feature>_page
  tests/test_<feature>_behavior
```

### Step 4: Add Behavior Tests Or Manual QA First

Before deep implementation, define how you will know it works.

At minimum:

- One happy path
- One failure path
- One edge case

### Step 5: Implement In Small Phases

Each phase should be independently testable.

Good phase size:

- 1-5 files changed
- 1 clear behavior added
- Focused tests run
- No unrelated refactor

### Step 6: Check Architecture Before Shipping

Before release:

- Run the review checklist.
- Check file sizes.
- Confirm no new hidden coupling.
- Confirm logs are useful and privacy-safe.
- Update docs if the module contract changed.

### Step 7: Record Decisions

Use an Architecture Decision Record when:

- Choosing between external providers
- Introducing a new framework
- Creating a cross-project convention
- Accepting meaningful technical debt
- Making a security/privacy tradeoff

## Enforcement

These standards are enforceable by default. Exceptions are allowed, but they must be visible.

An exception must include:

- What rule is being broken
- Why the exception is necessary
- What risk it creates
- When it should be revisited
- Which tests or checks reduce the risk

## Final Standard

Good architecture should make the product feel easier to build, not heavier. The best system is one where adding the next feature feels calm because the current code has clear names, small files, honest boundaries, and tests that protect the behavior users depend on.
