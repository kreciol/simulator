#!/bin/sh
# om-prepare-test-env: generated teardown (contract v2)
# history:
#   2026-10-20 generated: stops the static server the up script started
set -eu
cd "$(git rev-parse --show-toplevel)"
D=".ai/qa/test-env.json"
[ -f "$D" ] || exit 0
[ "$(jq -r '.startedByThisRepo // false' "$D")" = true ] || exit 0
pid=$(jq -r '.app.pid // empty' "$D")
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null || true; fi
jq '.status = "stopped"' "$D" > "$D.tmp" && mv "$D.tmp" "$D"
echo "TEST_ENV_STATUS=stopped"
