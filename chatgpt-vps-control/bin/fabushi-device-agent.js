#!/usr/bin/env node
import { startDeviceAgent } from "../lib/device-agent.js";

const agent = startDeviceAgent();
if (!agent) throw new Error("DEVICE_GATEWAY_URL is required.");
const registered = await agent.waitUntilRegistered(Number(process.env.DEVICE_REGISTRATION_WAIT_MS || 45_000));
console.log(`Fabushi controllable device online: ${registered.deviceId}${registered.expiresAt ? ` until ${registered.expiresAt}` : ""}.`);

let closing = false;
async function close(signal) {
  if (closing) return;
  closing = true;
  console.log(`Fabushi device agent stopping after ${signal}.`);
  await agent.stop();
  process.exit(0);
}
process.once("SIGINT", () => void close("SIGINT"));
process.once("SIGTERM", () => void close("SIGTERM"));
await new Promise(() => {});
