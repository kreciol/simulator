#!/usr/bin/env bash
# Tests publish-gh-pages.sh and preview-comment.sh against a local bare repository,
# with `gh` replaced by a stub. Needs only bash, git and jq; CI runs it in the test job.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLISH="$HERE/publish-gh-pages.sh"
COMMENT="$HERE/preview-comment.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export PUBLISH_BACKOFF_S=0
export RUNNER_TEMP="$TMP"

FAILURES=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1" >&2; FAILURES=$((FAILURES + 1)); }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }

BARE="$TMP/remote.git"
git init --quiet --bare "$BARE"
git clone --quiet "$BARE" "$TMP/work" 2>/dev/null
git -C "$TMP/work" config core.hooksPath .git/hooks

# --- gh stub: open PRs from a file; issue comments as JSON files ---
STUB="$TMP/stub"
mkdir -p "$STUB/bin" "$STUB/comments"
cat >"$STUB/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1 $2" = "pr list" ]; then
  [ -f "$STUB/open_prs_fail" ] && exit 1
  cat "$STUB/open_prs"
  exit 0
fi
[ "$1" = api ] || exit 3
shift
method=GET path="" body=""
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    -f) body="${2#body=}"; shift 2 ;;
    --paginate) shift ;;
    *) path="$1"; shift ;;
  esac
done
case "$method" in
  GET)
    if compgen -G "$STUB/comments/*.json" >/dev/null; then jq -s . "$STUB"/comments/*.json; else echo '[]'; fi ;;
  POST)
    id=$(( $(ls "$STUB/comments" | wc -l) + 100 ))
    jq -n --argjson id "$id" --arg b "$body" '{id: $id, body: $b, user: {login: "github-actions[bot]"}}' >"$STUB/comments/$id.json" ;;
  PATCH)
    id="${path##*/}"
    jq -n --argjson id "$id" --arg b "$body" '{id: $id, body: $b, user: {login: "github-actions[bot]"}}' >"$STUB/comments/$id.json" ;;
esac
EOF
chmod +x "$STUB/bin/gh"
export STUB PATH="$STUB/bin:$PATH"
printf '7\n8\n' >"$STUB/open_prs"

mkdir -p "$TMP/v1" "$TMP/v2" "$TMP/empty"
echo v1 >"$TMP/v1/index.html"; echo w1 >"$TMP/v1/index.wasm"
echo v2 >"$TMP/v2/index.html"; echo w2 >"$TMP/v2/index.wasm"

SHA_A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
SHA_B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
SHA_C=cccccccccccccccccccccccccccccccccccccccc

publish() { (cd "$TMP/work" && bash "$PUBLISH" "$@") 2>>"$TMP/log"; }
files() { git --git-dir="$BARE" ls-tree -r --name-only gh-pages; }
has() { files | grep -qx "$1"; }
lacks() { ! has "$1"; }
content() { git --git-dir="$BARE" archive gh-pages "$1" | tar -xO; }
tip() { git --git-dir="$BARE" rev-parse --quiet --verify refs/heads/gh-pages || true; }
single_commit() { [ "$(git --git-dir="$BARE" rev-list --count gh-pages)" = 1 ]; }

# --- publish-gh-pages.sh ---
publish preview 7 "$SHA_A" "$TMP/v1"
check "preview creates the branch with pr/7/<sha7>/" has pr/7/aaaaaaa/index.html
check "every publish keeps .nojekyll" has .nojekyll
check "the branch is one commit" single_commit

publish main "$TMP/v1"
check "main publishes the root" has index.html
check "main keeps open previews" has pr/7/aaaaaaa/index.wasm

publish preview 8 "$SHA_B" "$TMP/v2"
publish preview 7 "$SHA_C" "$TMP/v2"
check "a new SHA is published" has pr/7/ccccccc/index.html
check "the PR's older SHA is removed" lacks pr/7/aaaaaaa/index.html
check "other PRs' previews survive" has pr/8/bbbbbbb/index.html
check "a preview leaves the root untouched" [ "$(content index.html)" = v1 ]
check "still one commit" single_commit

publish remove 8
check "remove drops pr/<n>/" lacks pr/8/bbbbbbb/index.html
check "remove keeps other previews" has pr/7/ccccccc/index.html
check "remove keeps the root" has index.html

before="$(tip)"
publish remove 8
check "a no-change call pushes nothing" [ "$(tip)" = "$before" ]

if publish main "$TMP/empty"; then fail "main refuses a build without index.html"; else pass "main refuses a build without index.html"; fi
if publish preview 9 "$SHA_A" "$TMP/empty"; then fail "preview refuses a build without index.html"; else pass "preview refuses a build without index.html"; fi
if publish preview 9 abc "$TMP/v1"; then fail "preview refuses a short SHA"; else pass "preview refuses a short SHA"; fi
if publish remove ../x; then fail "remove refuses a non-numeric PR"; else pass "remove refuses a non-numeric PR"; fi
check "refused calls leave the branch alone" [ "$(tip)" = "$before" ]

publish preview 9 "$SHA_A" "$TMP/v1"
printf '9\n' >"$STUB/open_prs"
publish main "$TMP/v2"
check "main replaces the root" [ "$(content index.html)" = v2 ]
check "main prunes previews of closed PRs" lacks pr/7/ccccccc/index.html
check "main keeps previews of open PRs" has pr/9/aaaaaaa/index.html

touch "$STUB/open_prs_fail"
publish main "$TMP/v1"
check "a failed PR lookup prunes nothing" has pr/9/aaaaaaa/index.html
rm "$STUB/open_prs_fail"

# A concurrent writer pushes between our read and our push: the lease rejects the
# push, and the retry keeps both changes.
git clone --quiet --branch gh-pages "$BARE" "$TMP/other"
cat >"$TMP/work/.git/hooks/pre-push" <<EOF
#!/usr/bin/env bash
if [ ! -f "$TMP/raced" ]; then
  touch "$TMP/raced"
  echo concurrent >"$TMP/other/concurrent.txt"
  git -C "$TMP/other" add concurrent.txt
  git -C "$TMP/other" commit --quiet -m concurrent
  git -C "$TMP/other" push --quiet origin gh-pages
fi
EOF
chmod +x "$TMP/work/.git/hooks/pre-push"
publish preview 9 "$SHA_B" "$TMP/v2"
rm "$TMP/work/.git/hooks/pre-push"
check "a lost lease is retried" grep -q "push rejected (attempt 1/" "$TMP/log"
check "the retry keeps the concurrent write" has concurrent.txt
check "the retry applies its own change" has pr/9/bbbbbbb/index.html
check "one commit after a race" single_commit

# A failing git step must stop the script, never push a partial tree or delete the
# branch. A shim fails one git subcommand and passes the rest to the real git.
REAL_GIT="$(command -v git)"
mkdir -p "$TMP/gitshim"
cat >"$TMP/gitshim/git" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do [ "\$a" = "\$FAIL_GIT" ] && exit 1; done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$TMP/gitshim/git"
for sub in fetch archive write-tree commit-tree; do
  before="$(tip)"
  if (cd "$TMP/work" && FAIL_GIT="$sub" PATH="$TMP/gitshim:$PATH" bash "$PUBLISH" remove 9) 2>>"$TMP/log"; then
    fail "a failed git $sub fails the publish"
  else
    pass "a failed git $sub fails the publish"
  fi
  check "a failed git $sub leaves the branch alone" [ "$(tip)" = "$before" ]
done

# --- preview-comment.sh ---
comment() { bash "$COMMENT" "$@"; }
count() { ls "$STUB/comments" | wc -l | tr -d ' '; }
body() { jq -r .body "$STUB"/comments/*.json; }

jq -n '{id: 1, body: "<!-- pr-web-preview --> a human quoting the marker", user: {login: "someone"}}' >"$STUB/comments/1.json"
comment deployed 7 "$SHA_A" https://example.github.io/sim/
check "a human comment with the marker is left alone" grep -q "a human quoting" "$STUB/comments/1.json"
rm "$STUB/comments/1.json"
check "deployed creates one comment" [ "$(count)" = 1 ]
check "the comment links pr/<n>/<sha7>/" grep -q "https://example.github.io/sim/pr/7/aaaaaaa/" <<<"$(body)"
check "the comment carries the full SHA" grep -q "$SHA_A" <<<"$(body)"

comment deployed 7 "$SHA_C" https://example.github.io/sim
check "a new deploy updates the same comment" [ "$(count)" = 1 ]
check "the updated comment links the new SHA" grep -q "pr/7/ccccccc/" <<<"$(body)"

comment removed 7
check "removed rewrites the comment" grep -q "preview removed" <<<"$(body)"
check "removed keeps one comment" [ "$(count)" = 1 ]

rm "$STUB"/comments/*.json
comment removed 5
check "removed without a comment posts nothing" [ "$(count)" = 0 ]

if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES check(s) failed; script log:" >&2
  cat "$TMP/log" >&2
  exit 1
fi
echo "all checks passed"
