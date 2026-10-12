# Database schema

Use Drizzle with Neon PostgreSQL. Start with six tables for identity, ingestion, and summaries. Add pricing, rule, and webhook tables as those features are built.

This is a proposed schema, not an applied migration. The [backend plan](README.md) explains the flow and build order. Types below use PostgreSQL names; `?` means nullable.

## First six tables

### Users

A local record for a verified login identity.

| Field                         | Type              |
| ----------------------------- | ----------------- |
| `id`                          | uuid, primary key |
| `auth_issuer`, `auth_subject` | text              |
| `created_at`                  | timestamptz       |

Make `(auth_issuer, auth_subject)` unique. The login system verifies identity; email is not the authorization key.

### Projects

A project groups an application's usage and settings.

| Field           | Type                   |
| --------------- | ---------------------- |
| `id`            | uuid, primary key      |
| `owner_user_id` | uuid, references users |
| `name`          | text                   |
| `created_at`    | timestamptz            |
| `archived_at`   | timestamptz?           |

Recommend one owner initially. Shared access needs a membership table if we choose to support it. Settle archive behavior before exposing it; deletion must not accidentally remove usage history or retry identities.

### Ingestion keys

A project can have only one active ingestion key. It contains a UUID and a 256-bit random secret; the database stores only the secret's SHA-256 hash.

| Field                | Type                      |
| -------------------- | ------------------------- |
| `id`                 | uuid, primary key         |
| `project_id`         | uuid, references projects |
| `name`               | text                      |
| `secret_digest`      | bytea                     |
| `created_by_user_id` | uuid, references users    |
| `created_at`         | timestamptz               |
| `revoked_at`         | timestamptz?              |

Enforce this with a unique index on `project_id` where `revoked_at IS NULL`. Revoked rows stay as history; they are no longer usable keys. Creating another key while one is active returns `409`; use regeneration to replace it.

Check the hash with constant-time comparison and check revocation on every ingestion request, once for the whole batch. The [product specification](../specification.md#authentication-privacy-and-records) defines the lifetime: no automatic expiration, only revocation or regeneration.

Regeneration locks the project, revokes the old row, and creates a new UUID and secret in one transaction. Show the new credential once. Keep the old row as credential history; never replace its hash or reactivate it.

### Usage events

One row represents one logical provider call, even if the provider SDK retried internally.

| Field                                        | Type                           |
| -------------------------------------------- | ------------------------------ |
| `project_id`                                 | uuid                           |
| `event_id`                                   | text, supplied by the client   |
| `provider`, `operation`                      | text                           |
| `environment`, `key_label`                   | text?                          |
| `outcome`                                    | success or error               |
| `status_code`                                | smallint?                      |
| `started_at`, `received_at`                  | timestamptz                    |
| `duration_ms`                                | numeric(30,6)?                 |
| `provider_request_id`                        | text?                          |
| `provider_details`                           | jsonb?, approved fields only   |
| `schema_version`, `canonicalization_version` | integer                        |
| `canonical_content`                          | jsonb, normalized client event |

Primary key: `(project_id, event_id)`. `project_id` references projects; events do not store which key submitted them.

The relational fields support filtering. `canonical_content` preserves the original normalized event, including supplied cost, for duplicate comparison. Build both from the same validated object. Keep normalization versioned so old retries remain comparable. Receipt time and calculated costs are not client identity fields.

Events are immutable. A provider request ID is useful context but does not replace the Relay event ID. Environment and key label are safe strings initially; they need no separate tables until they have a management lifecycle.

### Event measurements

Keep each usage quantity and its unit separate.

| Field                        | Type          |
| ---------------------------- | ------------- |
| `project_id`                 | uuid          |
| `event_id`, `metric`, `unit` | text          |
| `quantity`                   | numeric(30,6) |

Primary key: `(project_id, event_id, metric, unit)`. Reference the event through `(project_id, event_id)`.

For example, one event can have 1,200 input tokens and 400 output tokens. It still counts as one call. Missing usage is different from an explicitly measured zero; tokens, pages, and messages are not one combined quantity.

### Event costs

One current accounting row per event. Keep it separate so pricing can finish without changing the original event.

| Field                              | Type                                                    |
| ---------------------------------- | ------------------------------------------------------- |
| `project_id`                       | uuid                                                    |
| `event_id`                         | text                                                    |
| `status`                           | pending, reported, estimated, unknown, or pricing_error |
| `amount`                           | numeric(30,12)?                                         |
| `currency`                         | text?                                                   |
| `pricing_version_id`               | uuid?, references pricing_versions when added           |
| `formula_version`, `reason_code`   | text?                                                   |
| `calculated_at`, `next_attempt_at` | timestamptz?                                            |
| `attempt_count`                    | integer                                                 |
| `updated_at`                       | timestamptz                                             |

Primary key and event reference: `(project_id, event_id)`. Save this row with the event and measurements in the same transaction; a foreign key alone does not guarantee every event has a cost row.

| Status          | Meaning and required data                                                          |
| --------------- | ---------------------------------------------------------------------------------- |
| `reported`      | Client supplied amount and currency; zero is valid                                 |
| `pending`       | Awaiting calculation; no amount/currency, next attempt scheduled                   |
| `estimated`     | Amount/currency plus matching price/formula version and calculation time           |
| `unknown`       | Missing usage/prices; no amount/currency, specific reason, no automatic retry      |
| `pricing_error` | Calculation failed; no amount/currency, specific reason and bounded retry attempts |

Enforce these shapes with database checks, including explicit null checks. Supplied cost takes precedence; never add an estimate on top. New prices do not rewrite previous estimates. Repricing needs calculation history and an agreed effect on alerts before we add it.

## Shared database rules

- Generate UUIDs on the server, except client event IDs. Use `timestamptz` for time.
- Keep money and quantities as decimal strings in TypeScript. Validate nonnegative, finite values and allowed precision before insertion; do not let PostgreSQL silently round submitted values. Proposed estimates round once to 12 decimal places before storage; confirm this precision against the first provider's rates.
- Validate all runtime input, including provider details. Database state checks supplement TypeScript types.
- Every project-owned relationship uses project-aware foreign keys. Add `UNIQUE(project_id, id)` to UUID parents that need those references. Every read/change also checks user access and filters by project.
- Start with event indexes on `(project_id, started_at)`, `(project_id, provider, started_at)`, and `(project_id, key_label, started_at)`. Add indexes for other queries when measured plans justify them.
- Keep revoked credentials and saved event IDs. Automatic expiry or destructive deletion needs an agreed history/replay policy.

## Tables added with later features

| Table                  | What it stores                                                                        |
| ---------------------- | ------------------------------------------------------------------------------------- |
| `pricing_versions`     | Provider, operation, model/region, effective dates, currency, source, formula version |
| `pricing_rates`        | Each version's metric/unit rate and billing quantity                                  |
| `alert_rules`          | Threshold and scope, definition revision, current trigger episode, next check         |
| `alerts`               | Immutable rule/value/window snapshot and fixed webhook payload                        |
| `webhook_endpoints`    | Project-owned URL, enabled state, current signing-key reference                       |
| `webhook_signing_keys` | Encrypted signing secrets and rotation/revocation state                               |
| `webhook_deliveries`   | Alert/endpoint pair, fixed destination/key, attempts, due time, claim, final state    |
| `webhook_attempts`     | Each send's timing and outcome, including an unknown outcome after a crash            |

Specify their exact columns when implementing each feature. These rules already matter for the overall design:

- Pricing uses event start time and explicit dimensions. Reject overlapping price versions; preserve the selected version. Cached tokens included in input must not be charged twice.
- Lock rule state during evaluation. Make `(project_id, rule_id, revision, episode)` unique for alerts, and save state/alert/deliveries together.
- Make the initial alert/endpoint delivery unique. Reserve attempts before sending, with a claim token and timeout. Do not hold database locks during HTTP. Save results only for the current claim; expired claims become unknown and consume retry budget.
- Keep webhook payload/destination fixed across automatic retries. Signing secrets must be encrypted and recoverable, unlike ingestion-key hashes. Retain keys while referenced delivery work needs them.

The [processing design](../features/event-recording/architecture.md) owns the detailed pricing, rule, delivery, and security guarantees. The [dry-run cases](README.md#end-to-end-dry-runs) become integration checks when the backend is implemented.
