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
  "mobile/ios/Fabushi/FabushiDeviceMeshAgent.swift",
  (source) => {
    let withSecurity = source.includes("import Security\n")
      ? source
      : source.replace("import Foundation\n", "import Foundation\nimport Security\n");
    return withSecurity.replace(
      "UInt64(1_000_000_000) << UInt64(exponent)",
      "UInt64(1_000_000_000) << exponent",
    );
  },
) || changed;

changed = update(
  "mobile/ios/Fabushi/FabushiMeshNodeIdentity.swift",
  (source) => {
    let synchronizable = `        // Explicitly disable synchronizable storage. A mesh node identity must\n        // never migrate through iCloud Keychain to another physical device.\n        privateAttributes[kSecAttrSynchronizable as String] = false\n\n`;
    let withoutUnsupportedAttribute = source.replace(synchronizable, "");
    if (withoutUnsupportedAttribute.includes("kSecAttrKeyClass as String: kSecAttrKeyClassPrivate")) {
      return withoutUnsupportedAttribute;
    }
    const before = "            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,\n            kSecReturnRef as String: true,\n";
    if (!withoutUnsupportedAttribute.includes(before)) {
      throw new Error("iOS node identity query source pattern not found");
    }
    return withoutUnsupportedAttribute.replace(
      before,
      "            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,\n            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,\n            kSecReturnRef as String: true,\n",
    );
  },
) || changed;

console.log(changed ? "Applied iOS device mesh compile fixes." : "iOS device mesh compile fixes already applied.");
