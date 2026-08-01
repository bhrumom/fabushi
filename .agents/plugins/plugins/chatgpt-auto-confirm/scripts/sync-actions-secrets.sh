#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY=${CHATGPT_AUTO_CONFIRM_REPOSITORY:-bhrumom/fabushi}
AUTH_PATH=${1:-}
SESSION_COOKIES_PATH=${2:-}
START=${3:-false}

if [ -z "$AUTH_PATH" ] || [ -z "$SESSION_COOKIES_PATH" ]; then
  echo "必须提供 authPath 和 sessionCookiesPath；命令不会读取 ChatGPT 桌面端会话。" >&2
  exit 2
fi
case "$START" in
  true|false) ;;
  *) echo "start 必须是 true 或 false。" >&2; exit 2 ;;
esac

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
if ! "$GH_CLI" auth status >/dev/null 2>&1; then
  echo "GitHub CLI 未登录；请先运行 gh auth login。" >&2
  exit 1
fi

validate_input() {
  path=$1
  label=$2
  if [ ! -f "$path" ] || [ ! -r "$path" ] || [ ! -s "$path" ]; then
    echo "$label 必须是可读的非空文件。" >&2
    exit 2
  fi
  encoded_size=$(base64 < "$path" | wc -c | tr -d '[:space:]')
  if [ "$encoded_size" -ge 47000 ]; then
    echo "$label 超过 GitHub Secret 大小限制。" >&2
    exit 2
  fi
}

upload_secret() {
  name=$1
  path=$2
  if ! base64 < "$path" | "$GH_CLI" secret set "$name" --repo "$REPOSITORY" >/dev/null; then
    echo "GitHub Secret 更新失败：$name。" >&2
    exit 1
  fi
}

validate_input "$AUTH_PATH" authPath
validate_input "$SESSION_COOKIES_PATH" sessionCookiesPath
upload_secret CHATGPT_CODEX_AUTH_B64 "$AUTH_PATH"
upload_secret CHATGPT_SESSION_COOKIES_B64 "$SESSION_COOKIES_PATH"

if [ "$START" = true ]; then
  CHATGPT_AUTO_CONFIRM_SKIP_CREDENTIAL_SYNC=true \
  CHATGPT_CODEX_AUTH_PATH="$AUTH_PATH" \
  CHATGPT_SESSION_COOKIES_PATH="$SESSION_COOKIES_PATH" \
  CHATGPT_AUTO_CONFIRM_DISPATCH=true \
    "$SCRIPT_DIR/dispatch-actions-runner.sh" >/dev/null
fi

printf '%s\n' '{"ok":true,"credentialsSynchronized":true,"started":'"$START"'}'
