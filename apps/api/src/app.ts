import express, { type Express } from "express";

export function createApp(): Express {
  const app = express();
  app.disable("x-powered-by");

  // Liveness only; database readiness will be checked separately when wired.
  app.get("/health", (_request, response) => {
    response.json({ status: "ok" });
  });

  app.use((_request, response) => {
    response.status(404).json({ error: "Route not found" });
  });

  return app;
}
