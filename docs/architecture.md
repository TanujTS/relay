# Relay: architecture

## Overview

    SDK → POST /v1/events → API → Postgres
                                    ↓
                     Worker: prices events, checks rules, sends webhooks

- **API** (`apps/api`): receives events, saves them, serves the dashboard.
- **Worker** (`apps/worker`): runs slower jobs so they never delay ingestion.
- **Postgres** (Neon, via Drizzle): the only data store. No queue or cache until a measured problem needs one.

Database code lives in `apps/api/src/db`; the API is its only current consumer. Copy `apps/api/.env.example` to `.env` and set the Neon connection URL. From `apps/api`, run `pnpm db:generate` after schema changes and `pnpm db:migrate` to apply committed migrations. The Better Auth core tables exist; login routes are not wired yet.

## Saving events

1. Read the key from `Authorization: Bearer relay_<key_id>.<secret>`. Look up the key row, hash the secret and compare, and check it isn't revoked. The key tells us the project.
2. Validate the batch with zod (max 100 events, 256 KiB).
3. In one database transaction, save each event with its measurements and a cost row.
4. Reply only after the transaction commits.

Each event is unique by `(project_id, event_id)`:

| What arrives               | What happens                               |
| -------------------------- | ------------------------------------------ |
| New event id               | Saved                                      |
| Same id, same content      | Reported as a duplicate, not counted again |
| Same id, different content | Reported as a conflict, nothing changes    |

If the reply is lost, the SDK retries the whole batch and gets "duplicate" for everything. One bad event does not reject the rest. The response lists a result for each event.

## Cost

- If the client sends a cost, it is saved as `reported`.
- Otherwise the cost is `unaccounted`, with a reason and no amount or currency. The worker will save it as `estimated` only when it can price the complete event.
- Estimates use the price in effect when the event started. Later price changes don't rewrite old estimates.

Measurements describe quantities, for example `input_tokens`, unit `token`, quantity `"1200"`. One event can have several measurements but only one current total cost. Aggregate measurements separately from call counts and costs to avoid multiplying totals when joining rows. Pricing tables and the worker are not implemented yet.

## Dashboard numbers

Plain SQL over saved events. Times are UTC. A window includes its start and excludes its end. No calls means no error rate, not 0%.

## Rules and alerts

The worker checks each rule on a schedule. An alert is created once when the condition becomes true, and not again until it has been false and then true again. The alert and its webhook job are saved in one transaction.

## Webhooks

The worker sends due webhooks, records each attempt, and retries a limited number of times. The same alert can arrive twice if a worker crashes mid-send, so customers deduplicate by event id. Payloads are signed, and destination URLs are checked to block private addresses. Details are written when this is built.

## Data rules

- Every project-owned table has `project_id`, and every query filters on it.
- Events never change after they are saved.
- A partial unique index allows only one active key per project.
- Cost lives in its own row so pricing can finish later without editing the event.

## Decisions

See `docs/decisions/`.

## Open questions

- Event size limits and timestamp skew
- Price precision and currency conversion
- Rule check interval and what happens when edited
