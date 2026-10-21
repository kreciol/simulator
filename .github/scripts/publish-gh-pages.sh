#!/usr/bin/env bash
# The only writer of the GitHub Pages branch (see docs/agents/project-setup.md).
#
#   publish-gh-pages.sh main <build-dir>               main's build at the site root; pr/ survives
#   publish-gh-pages.sh preview <pr> <sha> <build-dir> pr/<pr>/<sha7>/; older SHAs of that PR go
#   publish-gh-pages.sh remove <pr>                    drops pr/<pr>/
#
# Runs inside a checkout whose remote can be pushed to. The branch is always one
# parentless commit, pushed with a lease on the tip it read, so a concurrent writer
# is never overwritten: a lost lease re-reads and re-applies. `main` also prunes the
# previews of PRs that are no longer open (needs `gh` with a token).
#
# Env: PAGES_REMOTE (origin), PAGES_BRANCH (gh-pages), PUBLISH_MAX_ATTEMPTS (5),
#      PUBLISH_BACKOFF_S (3).
set -euo pipefail

REMOTE="${PAGES_REMOTE:-origin}"
BRANCH="${PAGES_BRANCH:-gh-pages}"
MAX_ATTEMPTS="${PUBLISH_MAX_ATTEMPTS:-5}"
BACKOFF_S="${PUBLISH_BACKOFF_S:-3}"

export GIT_AUTHOR_NAME="github-actions[bot]"
export GIT_AUTHOR_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

die() { echo "publish-gh-pages: $*" >&2; exit 2; }
log() { echo "publish-gh-pages: $*" >&2; }

require_build() {
  [ -f "$1/index.html" ] || die "'$1' has no index.html — refusing to publish an incomplete build"
}

require_pr() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "PR number '$1' is not a positive integer"
}

MODE="${1:-}"
case "$MODE" in
  main)
    [ $# -eq 2 ] || die "usage: main <build-dir>"
    BUILD_DIR="$2"
    require_build "$BUILD_DIR"
    MESSAGE="Publish main${GITHUB_SHA:+ at ${GITHUB_SHA:0:7}}"
    ;;
  preview)
    [ $# -eq 4 ] || die "usage: preview <pr> <sha> <build-dir>"
    PR="$2"; SHA="$3"; BUILD_DIR="$4"
    require_pr "$PR"
    [[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || die "SHA '$SHA' is not a full 40-character commit id"
    require_build "$BUILD_DIR"
    MESSAGE="Preview PR #$PR at ${SHA:0:7}"
    ;;
  remove)
    [ $# -eq 2 ] || die "usage: remove <pr>"
    PR="$2"
    require_pr "$PR"
    MESSAGE="Remove the preview of PR #$PR"
    ;;
  *)
    die "usage: publish-gh-pages.sh main|preview|remove ..."
    ;;
esac

# Open PR numbers, one per line; fails (non-zero) when they cannot be read, so a
# failed lookup never reads as "no PR is open".
open_prs() {
  gh pr list --state open --limit 1000 --json number --jq '.[].number'
}

# Applies the change to the site tree in $1.
apply_change() {
  local site="$1"
  case "$MODE" in
    main)
      find "$site" -mindepth 1 -maxdepth 1 ! -name pr ! -name .nojekyll -exec rm -rf {} +
      cp -R "$BUILD_DIR"/. "$site"/
      if [ -d "$site/pr" ]; then
        local open
        if open="$(open_prs)"; then
          local dir
          for dir in "$site"/pr/*/; do
            [ -d "$dir" ] || continue
            local n
            n="$(basename "$dir")"
            if ! grep -qx "$n" <<<"$open"; then
              log "pruning pr/$n/ (PR is not open)"
              rm -rf "$dir"
            fi
          done
        else
          log "could not list open PRs — skipping the prune"
        fi
      fi
      ;;
    preview)
      rm -rf "$site/pr/$PR"
      mkdir -p "$site/pr/$PR/${SHA:0:7}"
      cp -R "$BUILD_DIR"/. "$site/pr/$PR/${SHA:0:7}"/
      ;;
    remove)
      rm -rf "$site/pr/$PR"
      ;;
  esac
  touch "$site/.nojekyll"
}

WORK="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/gh-pages.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
TRACKING="refs/remotes/$REMOTE/$BRANCH"
GIT_DIR_ABS="$(git rev-parse --absolute-git-dir)"

# One read-apply-push pass. Sets PUBLISHED=1 when pushed or nothing changed, 0 when
# the lease was lost (someone else pushed first). Any other failure ends the script:
# it is never called in a condition, which would switch errexit off inside it, and
# every step that could leave a partial tree dies explicitly.
publish_once() {
  local exists tip site tree old_tree commit
  PUBLISHED=0
  exists="$(git ls-remote --heads "$REMOTE" "refs/heads/$BRANCH")" || die "cannot read $REMOTE"
  site="$WORK/site"
  rm -rf "$site" "$WORK/index"
  mkdir -p "$site"
  tip=""
  old_tree=""
  if [ -n "$exists" ]; then
    git fetch --quiet --depth 1 "$REMOTE" "+refs/heads/$BRANCH:$TRACKING" || die "cannot fetch $BRANCH"
    tip="$(git rev-parse --verify "$TRACKING^{commit}")" || die "cannot resolve $BRANCH"
    git archive "$tip" | tar -x -C "$site" || die "cannot unpack $BRANCH"
    old_tree="$(git rev-parse --verify "$tip^{tree}")" || die "cannot read the $BRANCH tree"
  fi

  apply_change "$site"

  tree="$(export GIT_INDEX_FILE="$WORK/index"
          git -C "$site" --git-dir="$GIT_DIR_ABS" --work-tree="$site" add -A -f . &&
          git write-tree)" || die "cannot build the site tree"
  [ -n "$tree" ] || die "empty site tree"
  if [ "$tree" = "$old_tree" ]; then
    log "nothing changed on $BRANCH"
    PUBLISHED=1
    return 0
  fi
  commit="$(git commit-tree "$tree" -m "$MESSAGE")" || die "cannot commit the site tree"
  [ -n "$commit" ] || die "empty commit id"
  if git push --quiet --force-with-lease="refs/heads/$BRANCH:$tip" "$REMOTE" "$commit:refs/heads/$BRANCH"; then
    log "$MESSAGE → $BRANCH ${commit:0:7}"
    PUBLISHED=1
  fi
}

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  publish_once
  [ "$PUBLISHED" = 1 ] && exit 0
  log "push rejected (attempt $attempt/$MAX_ATTEMPTS) — re-reading $BRANCH"
  sleep "$BACKOFF_S"
done
die "gave up after $MAX_ATTEMPTS attempts"
