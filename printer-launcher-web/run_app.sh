#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$ROOT_DIR/.printer-launcher-web.pid"
LOG_FILE="$ROOT_DIR/.printer-launcher-web.log"
APP_URL="http://127.0.0.1:4310"

if [[ -f "$PID_FILE" ]]; then
  EXISTING_PID="$(cat "$PID_FILE")"
  if kill -0 "$EXISTING_PID" 2>/dev/null; then
    open "$APP_URL"
    echo "Printer Launcher Web is already running on $APP_URL"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

cd "$ROOT_DIR"
nohup npm run start >"$LOG_FILE" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" >"$PID_FILE"

for _ in {1..40}; do
  if curl -fsS "$APP_URL/api/health" >/dev/null 2>&1; then
    open "$APP_URL"
    echo "Printer Launcher Web started on $APP_URL"
    exit 0
  fi
  sleep 0.5
done

echo "Server started but health check did not respond yet. See $LOG_FILE" >&2
open "$APP_URL"
