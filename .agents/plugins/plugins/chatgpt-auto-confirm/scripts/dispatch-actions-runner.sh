#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REPOSITORY=bhrumom/fabushi
STATE_PATH=${CHATGPT_AUTO_CONFIRM_QUEUE_STATE:-"$HOME/Library/Application Support/Mahayana/plugins/chatgpt-auto-confirm/queue-state.json"}
AUTH_PATH=${CHATGPT_CODEX_AUTH_PATH:-"$HOME/.codex/auth.json"}

if ! command -v gh >/dev/null 2>&1; then
  echo "没有找到 gh；请先安装 GitHub CLI 并完成 gh auth login。" >&2
  exit 1
fi
if [ ! -s "$STATE_PATH" ]; then
  echo "没有可上传的任务队列状态：$STATE_PATH" >&2
  exit 1
fi
if [ ! -s "$AUTH_PATH" ]; then
  echo "没有可上传的 ChatGPT 登录凭证：$AUTH_PATH" >&2
  exit 1
fi
AUTH_SIZE=$(base64 < "$AUTH_PATH" | wc -c | tr -d ' ')
if [ "$AUTH_SIZE" -ge 47000 ]; then
  echo "ChatGPT 登录凭证超过 GitHub Secret 大小限制。" >&2
  exit 1
fi
base64 < "$AUTH_PATH" |
  gh secret set CHATGPT_CODEX_AUTH_B64 --repo "$REPOSITORY"

INITIAL_STATE=$(CHATGPT_AUTO_CONFIRM_QUEUE_STATE="$STATE_PATH" \
  node "$SCRIPT_DIR/export-action-state.mjs")
printf '%s' "$INITIAL_STATE" |
  gh secret set CHATGPT_AUTO_CONFIRM_INITIAL_STATE_B64 --repo "$REPOSITORY"

if ! gh secret list --repo "$REPOSITORY" --json name --jq \
  'map(.name) | index("CHATGPT_AUTO_CONFIRM_STATE_KEY") != null' |
  grep -q true; then
  openssl rand -base64 48 |
    gh secret set CHATGPT_AUTO_CONFIRM_STATE_KEY --repo "$REPOSITORY"
fi

gh workflow run chatgpt-auto-confirm-runner.yml \
  --repo "$REPOSITORY" \
  --ref main
echo "已启动 GitHub Actions 持续运行器。"
