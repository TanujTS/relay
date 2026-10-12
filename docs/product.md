# Relay: product

Relay shows teams how their apps use external APIs: how many calls they make, what it costs, and what fails. It also alerts them when something crosses a limit.

## The problem

A team uses OpenAI, an email service, a document API and more. Each has its own dashboard, so nobody sees the total picture. Relay puts it in one place.

## How it works

Apps keep calling providers directly. After each call, the SDK sends Relay a small usage event.

    App → Provider API        (unchanged)
    App → SDK → Relay         (usage event)
    Relay → dashboard, alerts

## What an event looks like (draft)

```json
{
  "id": "evt_123",
  "provider": "openai",
  "operation": "chat.completions",
  "keyLabel": "openai-production",
  "environment": "production",
  "outcome": "success",
  "startedAt": "2026-10-13T10:00:00Z",
  "usage": [
    { "metric": "tokens", "unit": "input", "quantity": "1200" },
    { "metric": "tokens", "unit": "output", "quantity": "400" }
  ],
  "reportedCost": { "amount": "0.0123", "currency": "USD" }
}
```

`keyLabel` is a name like `openai-production`, never the real API key. `reportedCost` is optional.

## MVP

1. Login, projects, ingestion keys
2. Save events sent to the API
3. JavaScript/TypeScript SDK
4. Dashboard: call count, known cost, errors, error rate
5. Breakdowns by provider and key label, with a time filter
6. One alert rule (provider cost over a limit)
7. Alerts delivered by webhook, with history

## Not building

CPU/memory monitoring, tracing, log search, incident management, ML anomaly detection, invoice reconciliation, subscription tracking.

## Rules that matter

- Retries never double-count: the same event sent twice is counted once.
- Unknown cost is "unknown", never zero.
- Every cost has a currency and is marked "reported" or "estimated".
- Different units are never added together (tokens and pages stay separate).
- One project can never see another project's data.
- Each project has one active ingestion key. Revoked keys never come back.

## Open questions

- Which login provider?
- Which currencies, and do we convert between them?
- Do alerts also go by email?