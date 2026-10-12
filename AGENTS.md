# AGENTS.md

## What this is

Relay shows teams how their apps use third-party APIs (OpenAI, Resend, etc.): how many calls, what it costs, what fails. Apps send usage events to Relay through an SDK or HTTP. Relay never sits between an app and its providers.

Read `docs/product.md` for scope and `docs/architecture.md` for how it works.

## Layout

- `apps/api`: Express API
- `apps/web`: Next.js dashboard
- `apps/worker`: background jobs (pricing, rules, webhooks), not created yet
- `packages/db`, `packages/contracts`: planned

## Commands

`pnpm dev`, `pnpm lint`, `pnpm check-types`, `pnpm build`

## Rules

- Keep it simple. Build what the current step needs, no extra infrastructure.
- Stay in scope: API usage, cost, errors, alerts. No general logging or monitoring.
- Never store or log provider API keys or secrets.
- Validate all input with zod. Check project access on every project-scoped query.
- Money and quantities are decimal strings, never floats.
- Retrying an event must never count it twice.
- Add tests for new behavior and failure cases, especially duplicate events.
- Make focused changes. No unrelated refactors.
- If a requirement is unclear, ask instead of guessing.

## Docs

- Write docs when you build the feature, not before.
- Use plain words, short sentences, and an example for anything non-obvious.
- Say each fact once and link to it elsewhere.
- Add an ADR in `docs/decisions/` only when changing how events are saved, de-duplicated, priced or delivered, or when adding new infrastructure. Keep it under 20 lines.