import { drizzle, type NodePgDatabase } from "drizzle-orm/node-postgres";
import type { Pool } from "pg";
import { env } from "../env.js";
import * as schema from "./schema/index.js";

export const db: NodePgDatabase<typeof schema> & { $client: Pool } = drizzle({
  connection: env.DATABASE_URL,
  schema,
});
