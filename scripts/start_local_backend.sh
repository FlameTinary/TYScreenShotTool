#!/bin/zsh
#
# Start local AI Pro backend services:
# 1. Colima/Docker runtime
# 2. Local Supabase
# 3. Cloudflare Worker dev server

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUPABASE_DIR="$ROOT_DIR/backend/supabase"
WORKER_DIR="$ROOT_DIR/backend/worker"
PID_FILE="$ROOT_DIR/tmp/tshot-worker-dev.pid"
LOG_FILE="$ROOT_DIR/tmp/tshot-worker-dev.log"
WORKER_URL="http://127.0.0.1:8787"
WORKER_SCREEN_SESSION="tshot-worker-dev"

mkdir -p "$ROOT_DIR/tmp"

fail() {
  print -u2 "❌ $1"
  exit 1
}

info() {
  print "ℹ️  $1"
}

pass() {
  print "✅ $1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

wait_for_url() {
  local url="$1"
  local label="$2"
  local attempts="${3:-60}"

  for _ in $(seq 1 "$attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      pass "$label is ready: $url"
      return 0
    fi
    sleep 1
  done

  fail "$label did not become ready: $url"
}

ensure_colima() {
  require_command colima
  require_command docker

  if docker ps >/dev/null 2>&1; then
    pass "Docker is available"
    return
  fi

  info "Starting Colima..."
  colima start
  docker ps >/dev/null 2>&1 || fail "Docker is still unavailable after starting Colima."
  pass "Colima/Docker started"
}

ensure_supabase() {
  require_command supabase

  info "Starting local Supabase..."
  (
    cd "$SUPABASE_DIR"
    supabase start
  )

  wait_for_url "http://127.0.0.1:54321/rest/v1/" "Supabase REST API"
}

ensure_dev_vars() {
  local dev_vars="$WORKER_DIR/.dev.vars"

  if [[ -f "$dev_vars" ]]; then
    pass "Worker local secrets already exist: $dev_vars"
    return
  fi

  info "Creating Worker .dev.vars from local Supabase status..."
  local service_role_key
  service_role_key="$(
    cd "$SUPABASE_DIR"
    supabase status --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["SERVICE_ROLE_KEY"])'
  )"

  cat > "$dev_vars" <<EOF
# Local secrets for \`npm run dev\` / \`wrangler dev --env dev\`.
# This file is ignored by git. Do not commit real secrets.
SUPABASE_SERVICE_ROLE_KEY=$service_role_key
OPENAI_API_KEY=replace-with-local-or-test-openai-key
APPLE_ROOT_CERTIFICATES_PEM="-----BEGIN CERTIFICATE-----\nreplace-with-apple-root-certificate-pem\n-----END CERTIFICATE-----"
EOF
  chmod 600 "$dev_vars"
  pass "Created Worker local secrets: $dev_vars"
}

worker_pid_is_alive() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE")"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

worker_screen_is_alive() {
  local screen_list
  screen_list="$(screen -ls 2>/dev/null || true)"
  print -r -- "$screen_list" | rg -q "[[:space:]][0-9]+\\.${WORKER_SCREEN_SESSION}[[:space:]]"
}

ensure_worker() {
  if curl -fsS "$WORKER_URL/health" >/dev/null 2>&1; then
    pass "Worker is already ready: $WORKER_URL"
    return
  fi

  require_command screen

  if worker_screen_is_alive || worker_pid_is_alive; then
    info "Worker process exists but health check is not ready yet."
  else
    info "Starting Worker dev server in background..."
    : > "$LOG_FILE"
    screen -dmS "$WORKER_SCREEN_SESSION" zsh -lc "cd '$WORKER_DIR' && npm run dev >> '$LOG_FILE' 2>&1"
    local screen_list worker_pid
    screen_list="$(screen -ls 2>/dev/null || true)"
    worker_pid="$(print -r -- "$screen_list" | awk -v name="$WORKER_SCREEN_SESSION" '$0 ~ "\\." name "[[:space:]]" { split($1, parts, "."); print parts[1]; exit }' || true)"
    if [[ -n "$worker_pid" ]]; then
      print "$worker_pid" > "$PID_FILE"
    else
      rm -f "$PID_FILE"
    fi
  fi

  wait_for_url "$WORKER_URL/health" "Worker"
}

ensure_colima
ensure_supabase
ensure_dev_vars
ensure_worker

print ""
pass "Local backend is ready."
print "Supabase API: http://127.0.0.1:54321"
print "Supabase Studio: http://127.0.0.1:54323"
print "Worker: $WORKER_URL"
print "Worker log: $LOG_FILE"
