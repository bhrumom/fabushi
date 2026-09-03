#!/usr/bin/env node
import { createFabushiAccountSessionStore } from "../lib/fabushi-account-session.js";

const username = String(process.env.FABUSHI_TEST_ACCOUNT_USERNAME || "").trim();
const password = String(process.env.FABUSHI_TEST_ACCOUNT_PASSWORD || "");
const deviceId = String(process.env.DEVICE_ID || `gha-${process.env.GITHUB_RUN_ID || Date.now()}-${process.env.GITHUB_RUN_ATTEMPT || "1"}`).trim();
if (!username || !password) throw new Error("FABUSHI_TEST_ACCOUNT_USERNAME and FABUSHI_TEST_ACCOUNT_PASSWORD are required.");
const store = createFabushiAccountSessionStore();
const session = await store.login({ username, password, deviceId });
console.log(`Fabushi CI account session stored for ${session.username || session.userId || "test account"} on ${deviceId}.`);
