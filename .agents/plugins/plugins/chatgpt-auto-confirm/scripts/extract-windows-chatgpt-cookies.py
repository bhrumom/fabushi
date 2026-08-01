"""Extract ChatGPT/OpenAI browser cookies without printing their values.

This helper intentionally writes the cookie payload to a caller-provided file.
Its stdout is a small, non-sensitive JSON summary so the Windows host can pass
the result back to the miniapp without leaking a credential into logs.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path


DOMAINS = ("chatgpt.com", "openai.com")


class ExtractionError(RuntimeError):
    pass


def decrypt_cookie(encrypted_value, key, integrity_check):
    encrypted = bytes(encrypted_value or b"")
    if not encrypted:
        return ""
    if encrypted[:3] in (b"v10", b"v11"):
        payload = encrypted[3:]
        nonce, tag = payload[:12], payload[-16:]
        from Cryptodome.Cipher import AES
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        value = cipher.decrypt_and_verify(payload[12:-16], tag)
        if integrity_check and len(value) >= 32:
            value = value[32:]
        return value.decode("utf-8")
    if encrypted[:3] == b"v20":
        raise ExtractionError("Windows browser uses an unsupported app-bound cookie format v20")
    import win32crypt
    return win32crypt.CryptUnprotectData(encrypted, None, None, None, 0)[1].decode("utf-8")


def browser_key(key_file):
    import win32crypt
    local_state = json.loads(key_file.read_text(encoding="utf-8"))
    encrypted_key = base64.b64decode(local_state["os_crypt"]["encrypted_key"])[5:]
    return win32crypt.CryptUnprotectData(encrypted_key, None, None, None, 0)[1]


def validate_auth_bundle(auth_path):
    auth = json.loads(auth_path.read_text(encoding="utf-8"))
    tokens = auth.get("tokens") or {}
    account_id = auth.get("tokens", {}).get("account_id")
    id_token = tokens.get("id_token", "")
    if not account_id or not id_token or len(id_token.split(".")) < 2:
        raise ExtractionError("Codex auth bundle is incomplete")
    encoded_payload = id_token.split(".")[1]
    encoded_payload += "=" * ((4 - len(encoded_payload) % 4) % 4)
    payload = json.loads(base64.urlsafe_b64decode(encoded_payload))
    claims = payload.get("https://api.openai.com/auth") or {}
    if claims.get("chatgpt_account_id") != account_id:
        raise ExtractionError("Codex auth bundle account identifiers do not match")
    user_id = claims.get("chatgpt_user_id")
    if not user_id:
        raise ExtractionError("Codex auth bundle is missing the ChatGPT user identifier")
    return {"accountId": account_id, "userId": user_id}


def verify_web_account(cookies, identity):
    """Verify browser cookies belong to the same ChatGPT identity as auth.json."""
    cookie_header = "; ".join(
        f"{cookie['name']}={cookie['value']}" for cookie in cookies
    )
    request = urllib.request.Request(
        "https://chatgpt.com/api/auth/session",
        headers={
            "Accept": "application/json",
            "Cookie": cookie_header,
            "User-Agent": "Mozilla/5.0 Fabushi credential sync",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            if response.status != 200:
                raise ExtractionError("ChatGPT web session verification returned a non-success status")
            session = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, ValueError, json.JSONDecodeError, OSError) as error:
        raise ExtractionError("ChatGPT desktop session could not be reached or parsed") from error

    observed_ids = set()
    user = session.get("user") if isinstance(session, dict) else None
    if isinstance(user, dict):
        for key in ("id", "user_id", "account_id"):
            value = user.get(key)
            if value:
                observed_ids.add(str(value))
    for key in ("user_id", "chatgpt_user_id", "account_id", "chatgpt_account_id"):
        value = session.get(key) if isinstance(session, dict) else None
        if value:
            observed_ids.add(str(value))
    if not observed_ids:
        raise ExtractionError("ChatGPT desktop session did not return an account identity")
    expected_ids = {str(identity["userId"]), str(identity["accountId"])}
    if not observed_ids.intersection(expected_ids):
        raise ExtractionError("ChatGPT desktop session belongs to a different account")


def browser_profiles(browser_name):
    local_app_data = os.environ.get("LOCALAPPDATA", "")
    if not local_app_data:
        local_app_data = ""
    if browser_name == "codex":
        installed = set()
        if local_app_data:
            packages = Path(local_app_data) / "Packages"
            for package in packages.glob("OpenAI.Codex_*"):
                root = package / "LocalCache/Roaming/Codex"
                if not root.is_dir():
                    continue
                installed.update(root.glob("**/Cookies"))
        return sorted(cookie_db for cookie_db in installed if cookie_db.is_file())
    if not local_app_data:
        return []
    vendor = "Google\\Chrome" if browser_name == "chrome" else "Microsoft\\Edge"
    user_data = Path(local_app_data) / vendor / "User Data"
    if not user_data.is_dir():
        return []
    return sorted(
        cookie_db for profile in user_data.iterdir()
        if profile.is_dir()
        for cookie_db in (profile / "Network" / "Cookies",)
        if cookie_db.is_file()
    )


def normalize_cookie(cookie):
    domain = str(getattr(cookie, "domain", "") or "")
    name = str(getattr(cookie, "name", "") or "")
    value = str(getattr(cookie, "value", "") or "")
    if not name or not value:
        return None
    lower_domain = domain.lower().lstrip(".")
    if not any(lower_domain == domain_name or lower_domain.endswith("." + domain_name)
               for domain_name in DOMAINS):
        return None
    rest = getattr(cookie, "_rest", {}) or {}
    same_site = getattr(cookie, "samesite", None) or rest.get("SameSite") or "Lax"
    same_site = str(same_site).capitalize()
    if same_site not in {"Strict", "Lax", "None"}:
        same_site = "Lax"
    return {
        "name": name,
        "value": value,
        "domain": domain,
        "path": str(getattr(cookie, "path", "/") or "/"),
        "secure": bool(getattr(cookie, "secure", False)),
        "httpOnly": "HttpOnly" in rest,
        "sameSite": same_site,
    }


def extract(
    output_path: Path,
    auth_path: Path,
    source: str,
    verify_account: bool = False,
):
    try:
        import win32crypt  # noqa: F401 - dependency check for the DPAPI path
        from Cryptodome.Cipher import AES  # noqa: F401 - dependency check for AES-GCM
    except ImportError as error:
        raise RuntimeError("pywin32 and pycryptodome are required for Windows browser extraction") from error

    identity = validate_auth_bundle(auth_path)
    cookies = {}
    browser_sources = []
    candidate_rows = 0
    encrypted_prefixes = set()
    browser_names = {
        "desktop": ("codex",),
        "browser": ("edge", "chrome"),
        "auto": ("codex", "edge", "chrome"),
    }.get(source)
    if browser_names is None:
        raise ExtractionError("unsupported credential source")
    for browser_name in browser_names:
        source_count = 0
        for cookie_db in browser_profiles(browser_name):
            # Chromium keeps the live database open. A private copy avoids the
            # Windows shadow-copy/admin requirement and does not alter the browser.
            with tempfile.TemporaryDirectory(prefix="fabushi-cookie-") as temporary:
                copied_db = Path(temporary) / "Cookies"
                try:
                    shutil.copy2(cookie_db, copied_db)
                    for suffix in ("-wal", "-shm"):
                        sidecar = Path(str(cookie_db) + suffix)
                        if sidecar.is_file():
                            shutil.copy2(sidecar, Path(str(copied_db) + suffix))
                except OSError:
                    continue
                try:
                    connection = sqlite3.connect(str(copied_db))
                    try:
                        inventory = connection.execute(
                            "SELECT encrypted_value FROM cookies "
                            "WHERE host_key LIKE '%chatgpt%' OR host_key LIKE '%openai%'"
                        ).fetchall()
                    finally:
                        connection.close()
                    candidate_rows += len(inventory)
                    encrypted_prefixes.update(
                        bytes(row[0] or b"")[:3].decode("ascii", errors="replace")
                        for row in inventory
                    )
                except Exception:
                    pass
                try:
                    key_path = next(
                        (parent / "Local State" for parent in cookie_db.parents if (parent / "Local State").is_file()),
                        None,
                    )
                    if key_path is None:
                        continue
                    key = browser_key(key_path)
                    connection = sqlite3.connect(str(copied_db))
                    try:
                        version_row = connection.execute(
                            "SELECT value FROM meta WHERE key='version'"
                        ).fetchone()
                        integrity_check = bool(version_row and int(version_row[0]) >= 24)
                        rows = connection.execute(
                            "SELECT host_key, path, is_secure, name, value, encrypted_value, is_httponly "
                            "FROM cookies WHERE host_key LIKE '%chatgpt%' OR host_key LIKE '%openai%'"
                        ).fetchall()
                        for host, path, secure, name, plain_value, encrypted_value, http_only in rows:
                            try:
                                value = plain_value or decrypt_cookie(encrypted_value, key, integrity_check)
                            except Exception:
                                continue
                            normalized = normalize_cookie(type(
                                "Cookie", (), {
                                    "domain": host, "name": name, "value": value,
                                    "path": path, "secure": secure, "_rest": {
                                        "HttpOnly": None,
                                    } if http_only else {},
                                }
                            )())
                            if normalized is None:
                                continue
                            cookie_key = (normalized["domain"], normalized["path"], normalized["name"])
                            cookies[cookie_key] = normalized
                            source_count += 1
                    finally:
                        connection.close()
                except Exception:
                    # A locked, app-bound, or partially copied profile should
                    # not stop extraction from the other profile or browser.
                    continue
        if source_count:
            browser_sources.append("desktop-app" if browser_name == "codex" else browser_name)

    if not cookies:
        formats = ",".join(sorted(item for item in encrypted_prefixes if item)) or "none"
        raise ExtractionError(
            f"no usable ChatGPT/OpenAI cookies found; candidate rows={candidate_rows}; formats={formats}"
        )

    if verify_account:
        verify_web_account(list(cookies.values()), identity)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps({"cookies": list(cookies.values())}, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    try:
        os.chmod(output_path, 0o600)
    except OSError:
        pass
    return len(cookies), browser_sources


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--auth", required=True)
    parser.add_argument("--source", choices=("desktop", "browser", "auto"), default="desktop")
    parser.add_argument("--verify-account", action="store_true")
    args = parser.parse_args()
    try:
        count, sources = extract(
            Path(args.output).resolve(),
            Path(args.auth).resolve(),
            args.source,
            args.verify_account,
        )
        print(json.dumps({
            "ok": True,
            "cookieCount": count,
            "credentialSource": args.source,
            "browserSources": sources,
            "accountVerified": bool(args.verify_account),
        }, separators=(",", ":")))
        return 0
    except ImportError:
        message = "pywin32 and pycryptodome are required for Windows browser extraction"
        print(json.dumps({
            "ok": False,
            "errorCode": "chatgpt_cookie_extraction_dependency_missing",
            "message": message,
        }, separators=(",", ":")))
        return 1
    except ExtractionError as error:
        print(json.dumps({
            "ok": False,
            "errorCode": "chatgpt_cookie_extraction_failed",
            "message": str(error),
        }, separators=(",", ":")))
        return 1
    except Exception as error:
        print(json.dumps({
            "ok": False,
            "errorCode": "chatgpt_cookie_extraction_failed",
            "message": "no usable ChatGPT browser session cookies were found",
            "errorType": type(error).__name__,
        }, separators=(",", ":")))
        return 1


if __name__ == "__main__":
    sys.exit(main())
