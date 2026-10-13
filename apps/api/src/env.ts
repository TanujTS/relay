import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z
    .url()
    .refine(
      (value) => ["postgres:", "postgresql:"].includes(new URL(value).protocol),
      "DATABASE_URL must use the postgres or postgresql protocol",
    ),
  PORT: z
    .string()
    .regex(/^\d+$/, "PORT must contain only digits")
    .transform(Number)
    .pipe(z.number().int().min(1).max(65535))
    .default(8000),
});

// Validate before listening so invalid configuration fails at startup.
export const env = envSchema.parse({
  DATABASE_URL: process.env.DATABASE_URL,
  PORT: process.env.PORT,
});
