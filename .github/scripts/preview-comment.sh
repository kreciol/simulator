#!/usr/bin/env bash
# Keeps one bot comment per PR with its web preview link (see publish-gh-pages.sh).
#
#   preview-comment.sh deployed <pr> <sha> <site-url>   create or update the link comment
#   preview-comment.sh removed <pr>                     say the preview is gone (only if a comment exists)
#
# The comment is found by its hidden marker and bot author, and edited in place, never duplicated.
# Needs `gh` with a token that may write PR comments; the repository comes from
# GH_REPO or the checkout's remote.
set -euo pipefail

MARKER='<!-- pr-web-preview -->'
BOT='github-actions[bot]'  # the GITHUB_TOKEN's author; a human comment with the marker is left alone

die() { echo "preview-comment: $*" >&2; exit 2; }

find_comment() {
  gh api --paginate "repos/{owner}/{repo}/issues/$1/comments" |
    jq -r --arg m "$MARKER" --arg bot "$BOT" \
      '.[] | select(.user.login == $bot and (.body | startswith($m))) | .id' |
    tr -d '\r' | head -n 1
}

MODE="${1:-}"
case "$MODE" in
  deployed)
    [ $# -eq 4 ] || die "usage: deployed <pr> <sha> <site-url>"
    PR="$2"; SHA="$3"; SITE_URL="${4%/}"
    ;;
  removed)
    [ $# -eq 2 ] || die "usage: removed <pr>"
    PR="$2"
    ;;
  *)
    die "usage: preview-comment.sh deployed|removed ..."
    ;;
esac
[[ "$PR" =~ ^[1-9][0-9]*$ ]] || die "PR number '$PR' is not a positive integer"

ID="$(find_comment "$PR")"

if [ "$MODE" = deployed ]; then
  [[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || die "SHA '$SHA' is not a full 40-character commit id"
  BODY="$MARKER
🌐 **Web preview:** $SITE_URL/pr/$PR/${SHA:0:7}/
Head: \`$SHA\` — put this on the \`QA head:\` line.
Pages publishes about a minute after this comment; an older preview of this PR is gone."
else
  [ -n "$ID" ] || { echo "preview-comment: PR #$PR has no preview comment" >&2; exit 0; }
  BODY="$MARKER
🌐 Web preview removed — the PR is closed."
fi

if [ -n "$ID" ]; then
  gh api -X PATCH "repos/{owner}/{repo}/issues/comments/$ID" -f "body=$BODY" >/dev/null
else
  gh api -X POST "repos/{owner}/{repo}/issues/$PR/comments" -f "body=$BODY" >/dev/null
fi
