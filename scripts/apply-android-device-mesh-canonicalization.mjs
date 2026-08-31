import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiDeviceMeshAgent.kt");
let source = readFileSync(path, "utf8");
let changed = false;

if (!source.includes("// GBF-412 Android canonical schema hash")) {
  const before = "            val schemaVersion = sha256(catalog.toString().toByteArray())\n";
  if (!source.includes(before)) throw new Error("Android mesh schema hash source pattern not found");
  source = source.replace(
    before,
    "            val schemaVersion = sha256(canonicalJson(catalog).toByteArray(Charsets.UTF_8)) // GBF-412 Android canonical schema hash\n",
  );
  changed = true;
}

if (!source.includes("// GBF-412 Android canonical JSON")) {
  const before = "    private fun posture(appState: String): JSONObject = JSONObject()\n";
  if (!source.includes(before)) throw new Error("Android mesh posture source pattern not found");
  const canonical = `    private fun canonicalJson(value: Any?): String = when (value) {\n        null, JSONObject.NULL -> \"null\"\n        is String -> JSONObject.quote(value)\n        is Boolean -> if (value) \"true\" else \"false\"\n        is Number -> value.toString()\n        is JSONArray -> (0 until value.length()).joinToString(prefix = \"[\", postfix = \"]\", separator = \",\") { index ->\n            canonicalJson(value.opt(index))\n        }\n        is JSONObject -> value.keys().asSequence().toList().sorted().joinToString(\n            prefix = \"{\",\n            postfix = \"}\",\n            separator = \",\",\n        ) { key -> \"\${JSONObject.quote(key)}:\${canonicalJson(value.opt(key))}\" }\n        else -> error(\"Unsupported mesh canonical JSON value\")\n    } // GBF-412 Android canonical JSON\n\n`;
  source = source.replace(before, canonical + before);
  changed = true;
}

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied Android mesh canonicalization." : "Android mesh canonicalization already applied.");
