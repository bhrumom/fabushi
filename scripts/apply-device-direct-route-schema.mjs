import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "chatgpt-vps-control/lib/device-gateway.js");
let source = readFileSync(path, "utf8");
let changed = false;

function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing route schema anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  '  status: z.enum(["completed", "failed"]),\n  resultJson: z.string(),\n};\n',
  '  status: z.enum(["completed", "failed"]),\n' +
    '  route: z.enum(["direct-udp", "relay"]).optional(), // GBF-412 device call route output\n' +
    '  resultJson: z.string(),\n' +
    '};\n',
  '// GBF-412 device call route output',
);

replaceOnce(
  '          status: response.ok === false ? "failed" : "completed",\n          resultJson: JSON.stringify(response.result?.structuredContent ?? response.result ?? { error: response.error }),\n',
  '          status: response.ok === false ? "failed" : "completed",\n' +
    '          route: response.route === "direct-udp" ? "direct-udp" : "relay", // GBF-412 expose selected route\n' +
    '          resultJson: JSON.stringify(response.result?.structuredContent ?? response.result ?? { error: response.error }),\n',
  '// GBF-412 expose selected route',
);

replaceOnce(
  '          status: { type: "string", enum: ["completed", "failed"] }, resultJson: { type: "string" },\n',
  '          status: { type: "string", enum: ["completed", "failed"] }, route: { type: "string", enum: ["direct-udp", "relay"] }, resultJson: { type: "string" }, // GBF-412 route JSON schema\n',
  '// GBF-412 route JSON schema',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied device call route output schema." : "Device call route output schema already applied.");
