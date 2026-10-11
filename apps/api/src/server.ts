import { createApp } from "./app.js";
import { env } from "./env.js";

const port = env.PORT;
const server = createApp().listen(port, "0.0.0.0", () => {
  console.info(`Relay API listening on port ${port}`);
});

server.on("error", (error: NodeJS.ErrnoException) => {
  throw new Error(`API listen failed on port ${port}: ${error.code}`, { cause: error });
});
