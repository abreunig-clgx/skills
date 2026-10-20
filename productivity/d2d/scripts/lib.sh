# Shared helpers for d2d. Sourced, not run.

die() { echo "d2d: $*" >&2; exit 1; }

# The clone path is machine-specific, so it lives in a small pointer file in ~.
# Everything else lives in d2d.json inside the data repo and survives a wipe.
D2D_POINTER="${D2D_POINTER:-$HOME/.d2d-path}"

load_config() {
  DATA_DIR="${D2D_HOME:-}"
  if [ -z "$DATA_DIR" ] && [ -f "$D2D_POINTER" ]; then DATA_DIR=$(cat "$D2D_POINTER"); fi
  [ -d "${DATA_DIR:-}/.git" ] && [ -f "$DATA_DIR/d2d.json" ] \
    || die "not set up on this machine. Run /d2d (d2d setup --dir <path> --yes)"
  CONFIG="$DATA_DIR/d2d.json"
  OWNER=$(jq -r .owner "$CONFIG")
  DATA_REPO=$(jq -r .repo "$CONFIG")
}

today() { echo "${D2D_DATE:-$(date +%F)}"; }
now_hm() { echo "${D2D_TIME:-$(date +%H:%M)}"; }

# Commit everything in the data repo and push. A failed push is not fatal: the
# commit stays local and goes out with the next push.
data_commit() {
  git -C "$DATA_DIR" add -A
  git -C "$DATA_DIR" diff --cached --quiet && return 0
  git -C "$DATA_DIR" commit -q -m "$1"
  if ! git -C "$DATA_DIR" push -q -u origin HEAD 2>/dev/null; then
    git -C "$DATA_DIR" pull --rebase -q 2>/dev/null && git -C "$DATA_DIR" push -q -u origin HEAD 2>/dev/null \
      || echo "d2d: push failed; committed locally, will push next time" >&2
  fi
}

# owner/repo of the git repo in the current directory.
repo_from_cwd() {
  local u
  u=$(git remote get-url origin 2>/dev/null) || return 1
  u=${u%.git}
  echo "${u#*github.com[:/]}"
}

repo_slug() { echo "${1//\//__}"; }

tracked_repos() { jq -r '.tracked[]' "$CONFIG"; }

# Open "wayfinder:map" issues of a repo, as a JSON array with goal body and progress.
open_maps() { # repo
  gh api "repos/$1/issues?state=open&per_page=100" --paginate | jq -sc 'add // [] | map(
    select(has("pull_request")|not) | select(.labels|map(.name)|index("wayfinder:map"))
    | {number, title, url: .html_url, body: (.body // ""),
       done: (.sub_issues_summary.completed // 0), total: (.sub_issues_summary.total // 0)})'
}
