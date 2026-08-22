#!/usr/bin/env python3
"""Phase 3: promote worker_api include seams into real Rust submodules."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "third_party/mahayana/mahayana-rs/mahayana-platform-worker/src"
WORKER = SRC / "worker_api.rs"
PARTS = SRC / "worker_api_parts"
MODULES = SRC / "worker_api"
IDENTITY = SRC / "identity_auth.rs"
GUARD = ROOT / "fabushi/web/tests/platform-control-plane.test.js"


def read_part(name: str) -> str:
    path = PARTS / name
    if not path.exists():
        raise SystemExit(f"missing phase-2 part: {path}")
    return path.read_text(encoding="utf-8")


def expose_async_functions(source: str, prefix: str | None = None) -> str:
    if prefix is None:
        return re.sub(r"(?m)^async fn ([A-Za-z0-9_]+)\(", r"pub(super) async fn \1(", source)
    return re.sub(
        rf"(?m)^async fn ({re.escape(prefix)}[A-Za-z0-9_]*)\(",
        r"pub(super) async fn \1(",
        source,
    )


def module_text(body: str) -> str:
    return "use super::*;\n\n" + body.strip() + "\n"


def extract_security(ai_support: str) -> tuple[str, str]:
    start = ai_support.find("fn constant_time_eq(")
    end = ai_support.find("\nfn usage_limit_response", start)
    if start < 0 or end < 0:
        raise SystemExit("could not isolate constant_time_eq")
    security = ai_support[start:end].strip().replace(
        "fn constant_time_eq(", "pub(super) fn constant_time_eq(", 1
    )
    remaining = ai_support[:start] + ai_support[end + 1 :]
    return remaining, security


def write_modules() -> None:
    MODULES.mkdir(parents=True, exist_ok=True)
    if any(MODULES.iterdir()):
        raise SystemExit("worker_api module directory must be empty before phase 3")

    remote = read_part("remote_types.inc.rs") + "\n" + read_part("remote_control.inc.rs")
    remote = expose_async_functions(remote, "remote_computer_")
    (MODULES / "remote_computer.rs").write_text(module_text(remote), encoding="utf-8")

    listener = expose_async_functions(read_part("listener_relay.inc.rs"), "listener_")
    (MODULES / "listener_relay.rs").write_text(module_text(listener), encoding="utf-8")

    account = read_part("account_browser_auth.inc.rs") + "\n" + read_part("account_support.inc.rs")
    account = expose_async_functions(account)
    account = account.replace("fn authenticated_user(", "pub(super) fn authenticated_user(", 1)
    account = account.replace("fn authenticated_account(", "pub(super) fn authenticated_account(", 1)
    (MODULES / "account.rs").write_text(module_text(account), encoding="utf-8")

    ai_support, security = extract_security(read_part("ai_usage_support.inc.rs"))
    ai = read_part("ai_usage.inc.rs") + "\n" + ai_support
    ai = expose_async_functions(ai, "ai_usage_")
    (MODULES / "ai_usage.rs").write_text(module_text(ai), encoding="utf-8")
    (MODULES / "security.rs").write_text(security + "\n", encoding="utf-8")

    marketplace = expose_async_functions(read_part("marketplace.inc.rs"), "marketplace_")
    (MODULES / "marketplace.rs").write_text(module_text(marketplace), encoding="utf-8")

    commerce = expose_async_functions(read_part("commerce.inc.rs"))
    (MODULES / "commerce.rs").write_text(module_text(commerce), encoding="utf-8")


def rewrite_worker() -> None:
    source = WORKER.read_text(encoding="utf-8")
    include_names = [
        "remote_types.inc.rs",
        "remote_control.inc.rs",
        "listener_relay.inc.rs",
        "account_browser_auth.inc.rs",
        "ai_usage.inc.rs",
        "marketplace.inc.rs",
        "commerce.inc.rs",
        "ai_usage_support.inc.rs",
        "account_support.inc.rs",
    ]
    for name in include_names:
        pattern = re.compile(
            r"(?:\/\/[^\n]*\n){0,2}include!\(\"worker_api_parts/"
            + re.escape(name)
            + r"\"\);\n*"
        )
        source, count = pattern.subn("", source, count=1)
        if count != 1:
            raise SystemExit(f"expected exactly one include seam for {name}, found {count}")

    anchor = "#[event(fetch, respond_with_errors)]"
    if anchor not in source:
        raise SystemExit("worker entrypoint anchor missing")
    declarations = """mod account;
mod ai_usage;
mod commerce;
mod listener_relay;
mod marketplace;
mod remote_computer;
mod security;

use account::*;
use ai_usage::*;
use commerce::*;
use listener_relay::*;
use marketplace::*;
use remote_computer::*;
use security::constant_time_eq;

"""
    source = source.replace(anchor, declarations + anchor, 1)
    if "worker_api_parts/" in source:
        raise SystemExit("worker_api.rs still references transitional include parts")
    WORKER.write_text(source, encoding="utf-8")


def tighten_login_scope() -> None:
    source = IDENTITY.read_text(encoding="utf-8")
    old = 'scopes: "offline_access user-details.read",'
    new = 'scopes: "user-details.read",'
    if old in source:
        source = source.replace(old, new, 1)
    elif new not in source:
        raise SystemExit("Cloudflare identity scope moved unexpectedly")
    IDENTITY.write_text(source, encoding="utf-8")


def tighten_guard() -> None:
    source = GUARD.read_text(encoding="utf-8")
    anchor = "const rustWorker = read('../../third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api.rs');"
    module_checks = """const rustModuleRoot = '../../third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api';
for (const moduleName of ['account', 'ai_usage', 'commerce', 'listener_relay', 'marketplace', 'remote_computer', 'security']) {
  const moduleSource = read(`${rustModuleRoot}/${moduleName}.rs`);
  assert.doesNotMatch(moduleSource, /include!\\(/, `${moduleName}.rs must be a real module, not another include seam`);
}
assert.doesNotMatch(rustWorker, /worker_api_parts|include!\\(/, 'worker_api.rs must not retain transitional include seams');

const identityAuth = read('../../third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/identity_auth.rs');
assert.doesNotMatch(identityAuth, /offline_access/, 'sign-in gatekeepers must not request durable provider access');

"""
    if "const rustModuleRoot =" not in source:
        if anchor not in source:
            raise SystemExit("architecture guard worker anchor missing")
        # Insert module checks after worker size assertion block by using schema anchor.
        schema_anchor = "const accountMigration = read('../../third_party/mahayana/mahayana-rs/mahayana-platform-worker/account-migrations/0005_principals_connections.sql');"
        if schema_anchor not in source:
            raise SystemExit("architecture guard schema anchor missing")
        source = source.replace(schema_anchor, module_checks + schema_anchor, 1)
    GUARD.write_text(source, encoding="utf-8")


def remove_parts() -> None:
    for path in PARTS.glob("*.inc.rs"):
        path.unlink()
    try:
        PARTS.rmdir()
    except OSError as exc:
        raise SystemExit(f"transitional worker_api_parts directory is not empty: {exc}")


def main() -> None:
    if not PARTS.exists():
        print("phase-3 module promotion already applied")
        return
    write_modules()
    rewrite_worker()
    tighten_login_scope()
    tighten_guard()
    remove_parts()
    print("promoted worker_api include seams into explicit Rust modules")


if __name__ == "__main__":
    main()
