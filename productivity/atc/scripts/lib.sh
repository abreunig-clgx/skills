# Shared helpers for atc. Sourced, not run.

die() { echo "atc: $*" >&2; exit 1; }

ATC_CONFIG="${ATC_CONFIG:-$HOME/.config/atc/config.env}"

load_config() {
  [ -f "$ATC_CONFIG" ] || die "not set up. Run: atc setup --yes"
  # shellcheck disable=SC1090
  . "$ATC_CONFIG"
  INDEX="$DATA_DIR/index.tsv"
  PROJECTS="$DATA_DIR/projects.txt"
}

today() { echo "${ATC_DATE:-$(date +%F)}"; }
now_hm() { echo "${ATC_TIME:-$(date +%H:%M)}"; }

# Commit everything in the data repo and push. A failed push is not fatal: the
# commit stays local and goes out with the next push.
data_commit() {
  git -C "$DATA_DIR" add -A
  git -C "$DATA_DIR" diff --cached --quiet && return 0
  git -C "$DATA_DIR" commit -q -m "$1"
  if ! git -C "$DATA_DIR" push -q -u origin HEAD 2>/dev/null; then
    git -C "$DATA_DIR" pull --rebase -q 2>/dev/null && git -C "$DATA_DIR" push -q -u origin HEAD 2>/dev/null \
      || echo "atc: push failed; committed locally, will push next time" >&2
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

tracked_repos() { [ -f "$PROJECTS" ] && grep -v '^\s*$' "$PROJECTS" || true; }

# ---- index: key<TAB>stub<TAB>item<TAB>sig<TAB>touched<TAB>stage<TAB>state ----

idx_get() { [ -f "$INDEX" ] && awk -F'\t' -v k="$1" '$1==k' "$INDEX" || true; }

idx_put() { # key stub item sig touched stage state
  local tmp="$INDEX.tmp"
  { [ -f "$INDEX" ] && awk -F'\t' -v k="$1" '$1!=k' "$INDEX"; printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@"; } >"$tmp" || true
  mv "$tmp" "$INDEX"
}

idx_del() {
  [ -f "$INDEX" ] || return 0
  awk -F'\t' -v k="$1" '$1!=k' "$INDEX" >"$INDEX.tmp" || true
  mv "$INDEX.tmp" "$INDEX"
}

idx_keys_for_repo() { [ -f "$INDEX" ] && awk -F'\t' -v p="$1#" 'index($1,p)==1 {print $1}' "$INDEX" || true; }

# Open "wayfinder:map" issues of a repo, as a JSON array with goal body and progress.
open_maps() { # repo
  gh api "repos/$1/issues?state=open&per_page=100" --paginate | jq -sc 'add // [] | map(
    select(has("pull_request")|not) | select(.labels|map(.name)|index("wayfinder:map"))
    | {number, title, url: .html_url, body: (.body // ""),
       done: (.sub_issues_summary.completed // 0), total: (.sub_issues_summary.total // 0)})'
}
