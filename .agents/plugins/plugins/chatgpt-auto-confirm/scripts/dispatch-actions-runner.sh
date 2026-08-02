#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY=bhrumom/fabushi
AUTH_PATH=${CHATGPT_CODEX_AUTH_PATH:-"$HOME/.codex/auth.json"}
SESSION_COOKIES_PATH=${CHATGPT_SESSION_COOKIES_PATH:-"$HOME/Library/Application Support/Mahayana/plugins/chatgpt-auto-confirm/session-cookies.json"}

if command -v gh >/dev/null 2>&1; then
  GH_CLI=$(command -v gh)
elif [ -x /opt/homebrew/bin/gh ]; then
  GH_CLI=/opt/homebrew/bin/gh
elif [ -x /usr/local/bin/gh ]; then
  GH_CLI=/usr/local/bin/gh
else
  echo "没有找到 gh；请先安装 GitHub CLI 并完成 gh auth login。" >&2
  exit 1
fi
if [ ! -s "$AUTH_PATH" ]; then
  echo "没有可上传的 ChatGPT 登录凭证：$AUTH_PATH" >&2
  exit 1
fi
if [ ! -s "$SESSION_COOKIES_PATH" ]; then
  echo "没有可上传的 ChatGPT 会话凭证：${SESSION_COOKIES_PATH}；请先运行 login_and_sync_actions 完成登录。" >&2
  exit 1
fi
AUTH_SIZE=$(base64 < "$AUTH_PATH" | wc -c | tr -d ' ')
if [ "$AUTH_SIZE" -ge 47000 ]; then
  echo "ChatGPT 登录凭证超过 GitHub Secret 大小限制。" >&2
  exit 1
fi
SESSION_COOKIES_SIZE=$(base64 < "$SESSION_COOKIES_PATH" | wc -c | tr -d ' ')
if [ "$SESSION_COOKIES_SIZE" -ge 47000 ]; then
  echo "ChatGPT 会话凭证超过 GitHub Secret 大小限制。" >&2
  exit 1
fi
base64 < "$AUTH_PATH" |
  "$GH_CLI" secret set CHATGPT_CODEX_AUTH_B64 --repo "$REPOSITORY"
base64 < "$SESSION_COOKIES_PATH" |
  "$GH_CLI" secret set CHATGPT_SESSION_COOKIES_B64 --repo "$REPOSITORY"

if ! "$GH_CLI" secret list --repo "$REPOSITORY" --json name --jq \
  'map(.name) | index("CHATGPT_AUTO_CONFIRM_STATE_KEY") != null' |
  grep -q true; then
  openssl rand -base64 48 |
    "$GH_CLI" secret set CHATGPT_AUTO_CONFIRM_STATE_KEY --repo "$REPOSITORY"
fi

if [ "${CHATGPT_AUTO_CONFIRM_DISPATCH:-true}" = "true" ]; then
  "$GH_CLI" workflow run chatgpt-auto-confirm-runner.yml \
    --repo "$REPOSITORY" \
    --ref main
  echo "已启动 GitHub Actions 持续运行器。"
else
  echo "已同步 GitHub Actions 登录凭证。"
fi
