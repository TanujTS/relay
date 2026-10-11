# AGENTS.md

## Project Context

This repository implements an API usage intelligence platform focused on:

- usage
- cost
- errors
- alerts for third-party API/service consumption

Read `docs/specification.md` before making substantial product or architectural changes.

## General Rules

- Prefer the simplest correct implementation for current requirements.
- Do not introduce infrastructure or abstractions for hypothetical scale.
- Do not broaden the product into generic observability, logging, tracing, or infrastructure monitoring.
- Do not invent product requirements when behaviour is materially ambiguous.
- Preserve existing external contracts unless the task explicitly changes them.
- Treat correctness around usage, cost, retries, deduplication, and alerting as high priority.
- Never store or log real third-party API secrets in telemetry.
- Validate all untrusted runtime input.
- Enforce project-level data isolation and authorization.
- Prefer focused changes; avoid unrelated refactors.
- Add or update tests for changed behaviour and important failure paths.
- Before finishing, verify the implementation against the task, `docs/specification.md`, and relevant existing decisions.

## Architecture Decisions

Create or update an ADR only for significant architectural decisions, such as:

- introducing a queue, cache, or new datastore
- changing ingestion semantics
- changing deduplication or retry guarantees
- changing aggregation strategy
- changing webhook delivery semantics

Do not create ADRs for routine implementation details.

## Guiding Questions

For architectural complexity:

> What concrete problem requires this?

For product scope:

> Does this help users understand or act on external API usage, cost, or errors?

## Documentation Structure

- `docs/specification.md` — product scope, requirements, boundaries, core behavior.
- `docs/architecture/README.md` — current system architecture.
- `docs/architecture/decisions/` — ADRs for significant architectural decisions.
- `docs/features/<feature>/spec.md` — feature requirements and acceptance criteria.
- `docs/features/<feature>/plan.md` — implementation plan for that feature.

For substantial new features, create or update the relevant feature spec before implementation.

Do not create extra documentation files unless they add clear value.

## Documentation Style

Apply this style when creating or editing specifications, architecture documents, plans, and ADRs:

- Use plain, direct explanations with short paragraphs and descriptive headings.
- Start with the purpose and overall flow, then explain each part in the order a reader needs it.
- Show concrete examples of inputs, outcomes, retries, and failures alongside the behavior they illustrate.
- Use small Mermaid diagrams for flows and sequences, and tables for alternatives or repeated comparisons.
- Use technical terms where useful without adding glossary-style definitions; explain what the system does and why.
- Keep requirements, recommendations, and open decisions clearly distinguished. Preserve guarantees and failure limits when simplifying language.
- For material design choices, compare alternatives, recommend one with its reason, describe failures/limits, and state when to revisit it and whether an ADR is needed.
- Keep each rule in its owning document and link to it elsewhere. Use fenced blocks only for code, diagrams, or examples, not entire documents.

Before writing documentation, read `docs/features/event-recording/architecture.md` as the approved style reference. Match its plain explanations, concrete examples, and visual structure, scaling detail to the document's purpose.
