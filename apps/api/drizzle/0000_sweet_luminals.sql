CREATE TYPE "public"."cost_status" AS ENUM('reported', 'estimated', 'unaccounted');--> statement-breakpoint
CREATE TYPE "public"."event_outcome" AS ENUM('success', 'error');--> statement-breakpoint
CREATE TABLE "account" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"account_id" text NOT NULL,
	"provider_id" text NOT NULL,
	"access_token" text,
	"refresh_token" text,
	"id_token" text,
	"access_token_expires_at" timestamp with time zone,
	"refresh_token_expires_at" timestamp with time zone,
	"scope" text,
	"password" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "event_costs" (
	"project_id" uuid NOT NULL,
	"event_id" text NOT NULL,
	"status" "cost_status" NOT NULL,
	"amount" numeric(30, 12),
	"currency" text,
	"unaccounted_reason" text,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "event_costs_project_id_event_id_pk" PRIMARY KEY("project_id","event_id"),
	CONSTRAINT "event_costs_status_valid" CHECK (
    ("event_costs"."status" = 'unaccounted' AND "event_costs"."amount" IS NULL AND "event_costs"."currency" IS NULL
      AND "event_costs"."unaccounted_reason" IS NOT NULL AND length(trim("event_costs"."unaccounted_reason")) > 0)
    OR
    ("event_costs"."status" IN ('reported', 'estimated') AND "event_costs"."amount" IS NOT NULL
      AND "event_costs"."amount" >= 0 AND "event_costs"."amount" <> 'NaN'::numeric
      AND "event_costs"."currency" IS NOT NULL AND "event_costs"."currency" ~ '^[A-Z]{3}$'
      AND "event_costs"."unaccounted_reason" IS NULL)
  )
);
--> statement-breakpoint
CREATE TABLE "event_measurements" (
	"project_id" uuid NOT NULL,
	"event_id" text NOT NULL,
	"metric" text NOT NULL,
	"unit" text NOT NULL,
	"quantity" numeric(30, 12) NOT NULL,
	CONSTRAINT "event_measurements_project_id_event_id_metric_unit_pk" PRIMARY KEY("project_id","event_id","metric","unit"),
	CONSTRAINT "event_measurements_quantity_valid" CHECK ("event_measurements"."quantity" >= 0 AND "event_measurements"."quantity" <> 'NaN'::numeric)
);
--> statement-breakpoint
CREATE TABLE "ingestion_keys" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"project_id" uuid NOT NULL,
	"secret_hash" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"revoked_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "projects" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"owner_id" text NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "session" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"token" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"ip_address" text,
	"user_agent" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "session_token_unique" UNIQUE("token")
);
--> statement-breakpoint
CREATE TABLE "usage_events" (
	"project_id" uuid NOT NULL,
	"event_id" text NOT NULL,
	"provider" text NOT NULL,
	"operation" text NOT NULL,
	"model" text,
	"key_label" text,
	"outcome" "event_outcome" NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"received_at" timestamp with time zone DEFAULT now() NOT NULL,
	"payload_hash" text NOT NULL,
	CONSTRAINT "usage_events_project_id_event_id_pk" PRIMARY KEY("project_id","event_id")
);
--> statement-breakpoint
CREATE TABLE "user" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"email" text NOT NULL,
	"email_verified" boolean DEFAULT false NOT NULL,
	"image" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_email_unique" UNIQUE("email")
);
--> statement-breakpoint
CREATE TABLE "verification" (
	"id" text PRIMARY KEY NOT NULL,
	"identifier" text NOT NULL,
	"value" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "account" ADD CONSTRAINT "account_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "event_costs" ADD CONSTRAINT "event_costs_project_id_event_id_usage_events_project_id_event_id_fk" FOREIGN KEY ("project_id","event_id") REFERENCES "public"."usage_events"("project_id","event_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "event_measurements" ADD CONSTRAINT "event_measurements_project_id_event_id_usage_events_project_id_event_id_fk" FOREIGN KEY ("project_id","event_id") REFERENCES "public"."usage_events"("project_id","event_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ingestion_keys" ADD CONSTRAINT "ingestion_keys_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "projects" ADD CONSTRAINT "projects_owner_id_user_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session" ADD CONSTRAINT "session_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "usage_events" ADD CONSTRAINT "usage_events_project_id_projects_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "account_user_idx" ON "account" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "account_provider_identity_idx" ON "account" USING btree ("provider_id","account_id");--> statement-breakpoint
CREATE UNIQUE INDEX "ingestion_keys_one_active_per_project" ON "ingestion_keys" USING btree ("project_id") WHERE "ingestion_keys"."revoked_at" IS NULL;--> statement-breakpoint
CREATE INDEX "projects_owner_idx" ON "projects" USING btree ("owner_id");--> statement-breakpoint
CREATE INDEX "session_user_idx" ON "session" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "usage_events_project_time_idx" ON "usage_events" USING btree ("project_id","started_at");--> statement-breakpoint
CREATE INDEX "verification_identifier_idx" ON "verification" USING btree ("identifier");