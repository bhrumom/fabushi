import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MIGRATION = ROOT / "third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0006_miniapp_source_identity.sql"

conn = sqlite3.connect(":memory:")
conn.execute("CREATE TABLE marketplace_plugins (plugin_id TEXT PRIMARY KEY, publisher_user_id TEXT NOT NULL)")
conn.execute("CREATE TABLE plugin_releases (plugin_id TEXT NOT NULL, source_json TEXT NOT NULL DEFAULT '{}', published_at INTEGER NOT NULL)")
conn.execute("INSERT INTO marketplace_plugins(plugin_id, publisher_user_id) VALUES (?, ?)", ("io.mahayana.local", "local-user"))
conn.execute("INSERT INTO marketplace_plugins(plugin_id, publisher_user_id) VALUES (?, ?)", ("io.mahayana.user", "alice"))
conn.execute(
    "INSERT INTO plugin_releases(plugin_id, source_json, published_at) VALUES (?, ?, ?)",
    (
        "io.mahayana.user",
        json.dumps({
            "provider": "github",
            "repository": "alice/miniapp-demo",
            "repositoryId": 4242,
            "commitSha": "a" * 40,
        }),
        1,
    ),
)
conn.executescript(MIGRATION.read_text())

columns = [
    "author", "source_host", "source_custody", "source_provider", "source_actor",
    "source_transport", "repository_owner", "repository_name", "repository_id",
    "publisher", "official_status", "hosting_provider", "runtime_profile",
    "deployment_target", "source_identity_json",
]

def row(plugin_id):
    values = conn.execute(
        f"SELECT {', '.join(columns)} FROM marketplace_plugins WHERE plugin_id = ?",
        (plugin_id,),
    ).fetchone()
    assert values is not None
    return dict(zip(columns, values))

local = row("io.mahayana.local")
assert local == {
    "author": "local-user",
    "source_host": "local",
    "source_custody": "device",
    "source_provider": "local",
    "source_actor": "user",
    "source_transport": "local-fs",
    "repository_owner": None,
    "repository_name": None,
    "repository_id": None,
    "publisher": "local-user",
    "official_status": "unverified",
    "hosting_provider": "none",
    "runtime_profile": "local-web-wasm",
    "deployment_target": "local-only",
    "source_identity_json": "{}",
}

user = row("io.mahayana.user")
assert user["author"] == "alice"
assert user["publisher"] == "alice"
assert user["source_host"] == "github"
assert user["source_custody"] == "user-owned"
assert user["source_provider"] == "github"
assert user["source_actor"] == "user"
assert user["source_transport"] == "github-mcp"
assert user["repository_owner"] == "alice"
assert user["repository_name"] == "miniapp-demo"
assert user["repository_id"] == 4242
assert user["official_status"] == "unverified"
assert user["hosting_provider"] == "none"
assert user["runtime_profile"] == "local-web-wasm"
assert user["deployment_target"] == "user-github"
assert json.loads(user["source_identity_json"])["repositoryId"] == 4242

print("identity migration round-trip passed")
