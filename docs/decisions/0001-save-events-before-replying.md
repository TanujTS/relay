# 0001: Save events to Postgres before replying

Status: accepted

## Problem
How should Relay accept events so retries never double-count?

## Options
- Save directly to Postgres before replying: one place enforces uniqueness, but write speed is limited by the database.
- Put events on a queue first: handles bursts, but adds a system and a weaker "saved" meaning.

## Decision
Save in one transaction, unique on `(project_id, event_id)`, and reply only after commit. "Saved" is a real promise, and retries are safe.

## Revisit when
Measured write speed is too low, or we must accept events while the database is down.