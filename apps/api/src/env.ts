import { z } from "zod";

const envSchema = z.object({
  PORT: z.string()
    .regex(/^\d+$/, "PORT must contain only digits")
    .transform(Number)
    .pipe(z.number().int().min(1).max(65535)),
});

// Validate before listening so invalid configuration fails at startup.
export const env = envSchema.parse({ PORT: process.env.PORT });
