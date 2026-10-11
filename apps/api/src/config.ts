export function parsePort(value: string | undefined): number {
  if (value === undefined || !/^\d+$/.test(value)) {
    throw new TypeError("API startup failed: PORT must be an integer between 1 and 65535.");
  }

  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new RangeError("API startup failed: PORT must be between 1 and 65535.");
  }

  return port;
}
