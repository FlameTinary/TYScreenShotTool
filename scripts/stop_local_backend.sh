#!/bin/zsh
#
# Stop local AI Pro backend services started by start_local_backend.sh.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUPABASE_DIR="$ROOT_DIR/backend/supabase"
PID_FILE="$ROOT_DIR/tmp/tshot-worker-dev.pid"
WORKER_PORT="8787"
WORKER_SCREEN_SESSION="tshot-worker-dev"

info() {
  print "ℹ️  $1"
}

pass() {
  print "✅ $1"
}

stop_pid_tree() {
  local pid="$1"

  if [[ -z "$pid" ]] || ! kill -0 "$pid" >/dev/null 2>&1; then
    return 0
  fi

  # Stop child processes first so Wrangler can release workerd cleanly.
  local children
  children="$(pgrep -P "$pid" 2>/dev/null || true)"
  for child in ${(f)children}; do
    stop_pid_tree "$child"
  done

  kill "$pid" >/dev/null 2>&1 || true
}

stop_worker() {
  local stopped=false

  local screen_list
  screen_list="$(screen -ls 2>/dev/null || true)"
  if command -v screen >/dev/null 2>&1 \
    && print -r -- "$screen_list" | rg -q "[[:space:]][0-9]+\\.${WORKER_SCREEN_SESSION}[[:space:]]"; then
    info "Stopping Worker screen session: $WORKER_SCREEN_SESSION"
    screen -S "$WORKER_SCREEN_SESSION" -X quit >/dev/null 2>&1 || true
    stopped=true
  fi

  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      info "Stopping Worker dev process tree from PID file: $pid"
      stop_pid_tree "$pid"
      stopped=true
    fi
    rm -f "$PID_FILE"
  fi

  # If Worker was started manually, release the known local port as a fallback.
  local port_pids
  port_pids="$(lsof -tiTCP:"$WORKER_PORT" -sTCP:LISTEN 2>/dev/null || true)"
  for port_pid in ${(f)port_pids}; do
    if [[ -n "$port_pid" ]] && kill -0 "$port_pid" >/dev/null 2>&1; then
      info "Stopping process listening on port $WORKER_PORT: $port_pid"
      stop_pid_tree "$port_pid"
      stopped=true
    fi
  done

  if [[ "$stopped" == true ]]; then
    pass "Worker dev server stopped"
  else
    pass "Worker dev server was not running"
  fi
}

stop_supabase() {
  if ! command -v supabase >/dev/null 2>&1; then
    pass "Supabase CLI not found; skipped Supabase stop"
    return
  fi

  info "Stopping local Supabase..."
  (
    cd "$SUPABASE_DIR"
    supabase stop
  )
  pass "Local Supabase stopped"
}

stop_worker
stop_supabase

print ""
pass "Local backend stopped."
