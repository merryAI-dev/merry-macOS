#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$ROOT_DIR/.printer-launcher-web.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "Printer Launcher Web is not running."
  exit 0
fi

PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  echo "Stopped Printer Launcher Web ($PID)."
else
  echo "Stored PID $PID is not active."
fi

rm -f "$PID_FILE"
