import { sql } from "drizzle-orm";
import {
  check,
  foreignKey,
  index,
  numeric,
  pgEnum,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from "drizzle-orm/pg-core";
import { user } from "./auth.js";

export const eventOutcome = pgEnum("event_outcome", ["success", "error"]);
export const costStatus = pgEnum("cost_status", [
  "reported",
  "estimated",
  "unaccounted",
]);

export const projects = pgTable(
  "projects",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    ownerId: text("owner_id")
      .notNull()
      .references(() => user.id),
    name: text("name").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => new Date()),
  },
  (table) => [index("projects_owner_idx").on(table.ownerId)],
);

export const ingestionKeys = pgTable(
  "ingestion_keys",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    projectId: uuid("project_id")
      .notNull()
      .references(() => projects.id),
    secretHash: text("secret_hash").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
  },
  (table) => [
    // Revoked credentials remain available for history, but only one key can be active.
    uniqueIndex("ingestion_keys_one_active_per_project")
      .on(table.projectId)
      .where(sql`${table.revokedAt} IS NULL`),
  ],
);

export const usageEvents = pgTable(
  "usage_events",
  {
    projectId: uuid("project_id")
      .notNull()
      .references(() => projects.id),
    eventId: text("event_id").notNull(),
    provider: text("provider").notNull(),
    operation: text("operation").notNull(),
    model: text("model"),
    keyLabel: text("key_label"),
    outcome: eventOutcome("outcome").notNull(),
    startedAt: timestamp("started_at", { withTimezone: true }).notNull(),
    receivedAt: timestamp("received_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    // Hash normalized client content, including reported cost, never later estimates.
    payloadHash: text("payload_hash").notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.projectId, table.eventId] }),
    index("usage_events_project_time_idx").on(table.projectId, table.startedAt),
  ],
);

/** Each row measures one quantity, for example input_tokens / token / "1200". */
export const eventMeasurements = pgTable(
  "event_measurements",
  {
    projectId: uuid("project_id").notNull(),
    eventId: text("event_id").notNull(),
    metric: text("metric").notNull(),
    unit: text("unit").notNull(),
    quantity: numeric("quantity", { precision: 30, scale: 12 }).notNull(),
  },
  (table) => [
    primaryKey({
      columns: [table.projectId, table.eventId, table.metric, table.unit],
    }),
    // Including project_id prevents a child row from referencing another project's event.
    foreignKey({
      columns: [table.projectId, table.eventId],
      foreignColumns: [usageEvents.projectId, usageEvents.eventId],
    }),
    check(
      "event_measurements_quantity_valid",
      sql`${table.quantity} >= 0 AND ${table.quantity} <> 'NaN'::numeric`,
    ),
  ],
);

/** One current total per event; null means unaccounted, while an explicit zero is known. */
export const eventCosts = pgTable(
  "event_costs",
  {
    projectId: uuid("project_id").notNull(),
    eventId: text("event_id").notNull(),
    status: costStatus("status").notNull(),
    amount: numeric("amount", { precision: 30, scale: 12 }),
    currency: text("currency"),
    unaccountedReason: text("unaccounted_reason"),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => new Date()),
  },
  (table) => [
    primaryKey({ columns: [table.projectId, table.eventId] }),
    foreignKey({
      columns: [table.projectId, table.eventId],
      foreignColumns: [usageEvents.projectId, usageEvents.eventId],
    }),
    check(
      "event_costs_status_valid",
      sql`
    (${table.status} = 'unaccounted' AND ${table.amount} IS NULL AND ${table.currency} IS NULL
      AND ${table.unaccountedReason} IS NOT NULL AND length(trim(${table.unaccountedReason})) > 0)
    OR
    (${table.status} IN ('reported', 'estimated') AND ${table.amount} IS NOT NULL
      AND ${table.amount} >= 0 AND ${table.amount} <> 'NaN'::numeric
      AND ${table.currency} IS NOT NULL AND ${table.currency} ~ '^[A-Z]{3}$'
      AND ${table.unaccountedReason} IS NULL)
  `,
    ),
  ],
);
