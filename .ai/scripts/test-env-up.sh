#!/bin/sh
# om-prepare-test-env: generated entrypoint (contract v2)
# regenerate with: om-prepare-test-env --regenerate
# history:
#   2026-10-20 generated: Godot Web export served by a static HTTP server (no backing services; cold 16-28s, warm <1s)
#   2026-10-20 repair: pick python by running it (Windows Store python3 alias stub broke the server start)
set -eu

# --- project-specific variables -------------------------------------------
GODOT=${GODOT:-godot}
EXPORT_PRESET="Web"
BUILD_DIR="build/web"
BUILD_ARTIFACT="$BUILD_DIR/index.html"
PREFERRED_PORT=8060
HEALTH_PATH="/index.html"
QA_DIR=".ai/qa"
ENV_DESCRIPTOR="$QA_DIR/test-env.json"
BUILD_CACHE="$QA_DIR/test-env-build-cache.json"
LOG_FILE="$QA_DIR/test-env-server.log"
TTL=${TEST_ENV_CACHE_TTL_SECONDS:-600}
# ---------------------------------------------------------------------------

FORCE=0; FORCE_REBUILD=0
for a in "$@"; do
  case "$a" in --force) FORCE=1 ;; --force-rebuild) FORCE_REBUILD=1 ;; esac
done

cd "$(git rev-parse --show-toplevel)"
mkdir -p "$QA_DIR"

PY=""
# Probe by running it: on Windows `python3` may be the Microsoft Store alias stub.
for c in python3 python; do "$c" -c 'import http.server' >/dev/null 2>&1 && { PY=$c; break; }; done
[ -n "$PY" ] || { echo "python is required to serve the web build" >&2; exit 1; }

free_port() {
  "$PY" -c 'import socket,sys
p=int(sys.argv[1])
s=socket.socket()
try: s.bind(("127.0.0.1",p))
except OSError: s.bind(("127.0.0.1",0))
print(s.getsockname()[1]); s.close()' "$PREFERRED_PORT"
}
probe() { curl -fsS -o /dev/null --max-time 5 "$1"; }
now() { date -u +%FT%TZ; }
jget() { jq -r "$1 // empty" "$2" 2>/dev/null || true; }

# Fingerprint: HEAD + tracked/untracked source state, excluding agent and build dirs.
fingerprint() {
  { git rev-parse HEAD
    git status --porcelain --untracked-files=all -- . ':!.ai' ':!build' ':!.godot'
    git diff -- . ':!.ai' ':!build' ':!.godot'
    "$GODOT" --version
  } | cksum | awk '{print $1}'
}

# --- lock -------------------------------------------------------------------
LOCK="$QA_DIR/test-env.lock"
take_lock() {
  i=0
  while ! mkdir "$LOCK" 2>/dev/null; do
    owner=$(jget .pid "$LOCK/owner.json")
    if [ -z "$owner" ] || ! kill -0 "$owner" 2>/dev/null; then rm -rf "$LOCK"; continue; fi
    i=$((i+1)); [ $i -gt 150 ] && { echo "test-env lock held by $owner" >&2; exit 1; }
    sleep 2
  done
  printf '{"pid":%s,"source":"test-env-up.sh","acquiredAt":"%s"}\n' "$$" "$(now)" > "$LOCK/owner.json"
}
take_lock
trap 'rm -rf "$LOCK"' EXIT INT TERM

FP=$(fingerprint)

# --- reuse check --------------------------------------------------------------
if [ "$FORCE" = 0 ] && [ "$(jget .status "$ENV_DESCRIPTOR")" = running ]; then
  pid=$(jget .app.pid "$ENV_DESCRIPTOR"); url=$(jget .baseUrl "$ENV_DESCRIPTOR")
  fp_cache=$(jget .fingerprint "$BUILD_CACHE")
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && probe "$url$HEALTH_PATH" \
     && probe "$url/index.wasm" && [ "$fp_cache" = "$FP" ]; then
    echo "TEST_ENV_STATUS=running"; echo "TEST_ENV_BASE_URL=$url"
    echo "TEST_ENV_DESCRIPTOR=$ENV_DESCRIPTOR"; echo "TEST_ENV_REUSED=1"
    echo "BROWSER_PROVIDER=$(jget .browser.provider "$ENV_DESCRIPTOR")"
    echo "BROWSER_INSTALLED=$( [ "$(jget .browser.installed "$ENV_DESCRIPTOR")" = true ] && echo 1 || echo 0)"
    exit 0
  fi
fi
# Stale or forced: stop what this repo started.
sh "$(dirname "$0")/test-env-down.sh" >/dev/null 2>&1 || true

# --- build cache ---------------------------------------------------------------
REBUILT=0
if [ "$FORCE_REBUILD" = 1 ] || [ "$(jget .fingerprint "$BUILD_CACHE")" != "$FP" ] || [ ! -s "$BUILD_ARTIFACT" ] || [ ! -s "$BUILD_DIR/index.wasm" ]; then
  mkdir -p "$BUILD_DIR"
  "$GODOT" --headless --path . --import
  "$GODOT" --headless --path . --export-release "$EXPORT_PRESET" "$BUILD_ARTIFACT"
  [ -s "$BUILD_ARTIFACT" ] || { echo "web export produced no $BUILD_ARTIFACT" >&2; exit 1; }
  printf '{"fingerprint":"%s","artifact":"%s","builtAt":"%s"}\n' "$FP" "$BUILD_ARTIFACT" "$(now)" > "$BUILD_CACHE"
  REBUILT=1
fi

# --- app start + health wait ---------------------------------------------------
PORT=$(free_port)
nohup "$PY" -m http.server "$PORT" --bind 127.0.0.1 --directory "$BUILD_DIR" > "$LOG_FILE" 2>&1 &
APP_PID=$!
BASE_URL="http://127.0.0.1:$PORT"
i=0
until probe "$BASE_URL$HEALTH_PATH"; do
  i=$((i+1)); [ $i -gt 60 ] && { echo "server did not become healthy" >&2; kill "$APP_PID" 2>/dev/null; exit 1; }
  sleep 0.5
done

# --- descriptor ------------------------------------------------------------------
BP=agent-browser; BINST=false; BCMD=""; BVER=""
AB=$(command -v agent-browser 2>/dev/null || ls "${XDG_CACHE_HOME:-$HOME/.cache}"/agent-tools/agent-browser/*/agent-browser* 2>/dev/null | head -1 || true)
if [ -n "$AB" ]; then BCMD=$AB; BINST=true; BVER=$("$AB" --version 2>/dev/null || echo unknown); fi
jq -n --arg url "$BASE_URL" --argjson port "$PORT" --argjson pid "$APP_PID" --arg started "$(now)" \
  --arg bcmd "$BCMD" --arg bver "$BVER" --argjson binst "$BINST" --arg bp "$BP" \
  --arg plat "$(case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) echo win32 ;; Darwin) echo darwin ;; *) echo linux ;; esac)" '{
  version: 1, runId: $started, status: "running", mode: "discovered", baseUrl: $url,
  startedByThisRepo: true, startScript: ".ai/scripts/test-env-up.sh", stopScript: ".ai/scripts/test-env-down.sh",
  app: { startCommand: "python -m http.server (build/web)", port: $port, healthPath: "/index.html", pid: $pid },
  services: [], credentials: [],
  browser: { provider: $bp, installed: $binst, command: $bcmd, version: $bver, descriptor: (".ai/browsers/" + $bp + ".md"), notes: "" },
  testRunner: { name: "none", config: "" }, platform: $plat, startedAt: $started,
  notes: "Godot Web export (godot --export-release Web build/web/index.html) served statically. Dev-launcher URL params work, e.g. ?screen=tutorial. Canvas-rendered game: the DOM has no UI elements, drive it with keyboard/mouse and screenshots."
}' > "$ENV_DESCRIPTOR"

echo "TEST_ENV_STATUS=running"; echo "TEST_ENV_BASE_URL=$BASE_URL"
echo "TEST_ENV_DESCRIPTOR=$ENV_DESCRIPTOR"; echo "TEST_ENV_REUSED=0"; echo "TEST_ENV_REBUILT=$REBUILT"
echo "BROWSER_PROVIDER=$BP"; echo "BROWSER_INSTALLED=$( [ "$BINST" = true ] && echo 1 || echo 0)"
