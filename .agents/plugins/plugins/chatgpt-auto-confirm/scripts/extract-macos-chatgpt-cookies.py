"""Extract and verify a matching ChatGPT Chrome session on macOS.

Cookie values are written only to the requested private output file. Stdout is
limited to a non-sensitive JSON summary so credentials never enter CLI or CI
logs.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path


DOMAINS = ("chatgpt.com", "openai.com")
CHROME_ROOT = Path.home() / "Library/Application Support/Google/Chrome"


class ExtractionError(RuntimeError):
    pass


def validate_auth_bundle(auth_path: Path):
    auth = json.loads(auth_path.read_text(encoding="utf-8"))
    tokens = auth.get("tokens") or {}
    account_id = tokens.get("account_id")
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
    return {"accountId": str(account_id), "userId": str(user_id)}


def chrome_password():
    try:
        result = subprocess.run(
            ["/usr/bin/security", "find-generic-password", "-w", "-s", "Chrome Safe Storage"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=120,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise ExtractionError(
            "Chrome Safe Storage access was not granted; allow the macOS Keychain prompt and retry"
        ) from error
    password = result.stdout.rstrip(b"\r\n")
    if not password:
        raise ExtractionError("Chrome Safe Storage returned an empty password")
    return password


def chrome_key(password: bytes):
    return hashlib.pbkdf2_hmac("sha1", password, b"saltysalt", 1003, dklen=16)


def decrypt_cookie(encrypted_value, key: bytes, host: str, integrity_check: bool):
    encrypted = bytes(encrypted_value or b"")
    if not encrypted:
        return ""
    if encrypted[:3] not in (b"v10", b"v11"):
        raise ExtractionError("Chrome cookie uses an unsupported encryption format")
    try:
        result = subprocess.run(
            [
                "/usr/bin/openssl", "enc", "-d", "-aes-128-cbc",
                "-K", key.hex(), "-iv", (b" " * 16).hex(), "-nopad",
            ],
            input=encrypted[3:],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise ExtractionError("Chrome cookie decryption failed") from error
    value = result.stdout
    if not value:
        return ""
    padding = value[-1]
    if padding < 1 or padding > 16 or value[-padding:] != bytes([padding]) * padding:
        raise ExtractionError("Chrome cookie padding is invalid")
    value = value[:-padding]
    if integrity_check:
        expected = hashlib.sha256(host.encode("utf-8")).digest()
        if not value.startswith(expected):
            raise ExtractionError("Chrome cookie host integrity check failed")
        value = value[len(expected):]
    return value.decode("utf-8")


def cookie_databases():
    if not CHROME_ROOT.is_dir():
        return []
    profiles = [CHROME_ROOT / "Default"] + sorted(CHROME_ROOT.glob("Profile *"))
    databases = []
    for profile in profiles:
        for candidate in (profile / "Network/Cookies", profile / "Cookies"):
            if candidate.is_file():
                databases.append(candidate)
                break
    return databases


def chromium_expiry(value):
    try:
        raw = int(value or 0)
    except (TypeError, ValueError):
        return None
    if raw <= 0:
        return None
    unix_seconds = raw / 1_000_000 - 11_644_473_600
    return unix_seconds if unix_seconds > 0 else None


def profile_cookies(cookie_db: Path, key: bytes):
    with tempfile.TemporaryDirectory(prefix="fabushi-cookie-") as temporary:
        copied_db = Path(temporary) / "Cookies"
        shutil.copy2(cookie_db, copied_db)
        for suffix in ("-wal", "-shm"):
            sidecar = Path(str(cookie_db) + suffix)
            if sidecar.is_file():
                shutil.copy2(sidecar, Path(str(copied_db) + suffix))
        connection = sqlite3.connect(str(copied_db))
        try:
            version_row = connection.execute(
                "SELECT value FROM meta WHERE key='version'"
            ).fetchone()
            integrity_check = bool(version_row and int(version_row[0]) >= 24)
            rows = connection.execute(
                "SELECT host_key,path,is_secure,name,value,encrypted_value,is_httponly,"
                "samesite,expires_utc FROM cookies "
                "WHERE host_key LIKE '%chatgpt.com' OR host_key LIKE '%openai.com'"
            ).fetchall()
        finally:
            connection.close()

    cookies = []
    for host, path, secure, name, plain, encrypted, http_only, same_site, expires in rows:
        try:
            value = plain or decrypt_cookie(encrypted, key, host, integrity_check)
        except (ExtractionError, UnicodeDecodeError):
            continue
        lower_host = str(host or "").lower().lstrip(".")
        if not name or not value or not any(
            lower_host == domain or lower_host.endswith("." + domain) for domain in DOMAINS
        ):
            continue
        cookie = {
            "name": str(name),
            "value": value,
            "domain": str(host),
            "path": str(path or "/"),
            "secure": bool(secure),
            "httpOnly": bool(http_only),
        }
        same_site_name = {0: "None", 1: "Lax", 2: "Strict"}.get(same_site)
        if same_site_name:
            cookie["sameSite"] = same_site_name
        expiry = chromium_expiry(expires)
        if expiry:
            cookie["expires"] = expiry
        cookies.append(cookie)
    return cookies


def verify_web_account(cookies, identity):
    chatgpt_cookies = [
        cookie for cookie in cookies
        if str(cookie.get("domain", "")).lower().lstrip(".") == "chatgpt.com"
        or str(cookie.get("domain", "")).lower().lstrip(".").endswith(".chatgpt.com")
    ]
    cookie_header = "; ".join(
        f"{cookie['name']}={cookie['value']}" for cookie in chatgpt_cookies
    )
    request = urllib.request.Request(
        "https://chatgpt.com/api/auth/session",
        headers={
            "Accept": "application/json",
            "Cookie": cookie_header,
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                          "(KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            session = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, ValueError, json.JSONDecodeError, OSError) as error:
        raise ExtractionError("ChatGPT web session could not be verified") from error
    observed_ids = set()
    user = session.get("user") if isinstance(session, dict) else None
    if isinstance(user, dict):
        for name in ("id", "user_id", "account_id"):
            if user.get(name):
                observed_ids.add(str(user[name]))
    if isinstance(session, dict):
        for name in ("user_id", "chatgpt_user_id", "account_id", "chatgpt_account_id"):
            if session.get(name):
                observed_ids.add(str(session[name]))
    expected_ids = {identity["userId"], identity["accountId"]}
    if not observed_ids.intersection(expected_ids):
        raise ExtractionError("ChatGPT web session belongs to a different account")


def extract(output_path: Path, auth_path: Path):
    identity = validate_auth_bundle(auth_path)
    key = chrome_key(chrome_password())
    failures = []
    for cookie_db in cookie_databases():
        try:
            cookies = profile_cookies(cookie_db, key)
            names = {cookie["name"] for cookie in cookies}
            if not any(name.startswith("__Secure-next-auth.session-token") for name in names):
                continue
            verify_web_account(cookies, identity)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(
                json.dumps({"cookies": cookies}, ensure_ascii=False, separators=(",", ":")),
                encoding="utf-8",
            )
            os.chmod(output_path, 0o600)
            return len(cookies), cookie_db.parent.name
        except (ExtractionError, OSError, sqlite3.Error) as error:
            failures.append(str(error))
    if failures:
        raise ExtractionError("no Chrome ChatGPT session matched the current Codex account")
    raise ExtractionError("no authenticated ChatGPT Chrome session was found")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--auth", required=True)
    args = parser.parse_args()
    try:
        count, profile = extract(Path(args.output).resolve(), Path(args.auth).resolve())
        print(json.dumps({
            "ok": True,
            "cookieCount": count,
            "credentialSource": "chrome",
            "profile": profile,
            "accountVerified": True,
        }, separators=(",", ":")))
        return 0
    except ExtractionError as error:
        print(json.dumps({
            "ok": False,
            "errorCode": "chatgpt_cookie_extraction_failed",
            "message": str(error),
        }, separators=(",", ":")))
        return 1
    except Exception:
        print(json.dumps({
            "ok": False,
            "errorCode": "chatgpt_cookie_extraction_failed",
            "message": "no usable matching ChatGPT Chrome session was found",
        }, separators=(",", ":")))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
