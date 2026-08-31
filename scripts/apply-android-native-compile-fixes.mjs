import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

function update(path, transform) {
  const target = resolve(process.cwd(), path);
  const source = readFileSync(target, "utf8");
  const next = transform(source);
  if (next === source) return false;
  writeFileSync(target, next);
  return true;
}

let changed = false;

changed = update(
  "mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiScreen.kt",
  (source) => source.replace("import androidx.compose.runtime.onDispose\n", ""),
) || changed;

changed = update(
  "mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiAppAgentSurface.kt",
  (source) => {
    if (source.includes("// GBF-412 bounded Android semantic wait")) return source;
    const before = `        val satisfied = withTimeoutOrNull(bounded) {\n            while (true) {\n                val result = assertState(expectedScreen, agentId, role, name, state)\n                if (result.passed) return@withTimeoutOrNull result\n                delay(100)\n            }\n        }\n        return satisfied ?: assertState(expectedScreen, agentId, role, name, state)\n`;
    const after = `        val satisfied = withTimeoutOrNull(bounded) {\n            var result = assertState(expectedScreen, agentId, role, name, state)\n            while (!result.passed) {\n                delay(100)\n                result = assertState(expectedScreen, agentId, role, name, state)\n            }\n            result\n        }\n        return satisfied ?: assertState(expectedScreen, agentId, role, name, state) // GBF-412 bounded Android semantic wait\n`;
    if (!source.includes(before)) {
      throw new Error("Android App MCP waitFor source pattern not found");
    }
    return source.replace(before, after);
  },
) || changed;

console.log(changed ? "Applied Android native compile fixes." : "Android native compile fixes already applied.");
