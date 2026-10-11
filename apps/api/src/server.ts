import { createApp } from "./app.js";
import { parsePort } from "./config.js";

const port = parsePort(process.env.PORT);
const server = createApp().listen(port, "0.0.0.0", () => {
  console.info(`Relay API listening on port ${port}`);
});

server.on("error", (error: NodeJS.ErrnoException) => {
  throw new Error(`API listen failed on port ${port}: ${error.code}`, { cause: error });
});
