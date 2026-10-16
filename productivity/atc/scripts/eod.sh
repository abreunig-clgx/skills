# jot, jots, contributions, write helpers, brief, status

cmd_jot() {
  load_config
  local repo="" issue="" map="" session="${COPILOT_AGENT_SESSION_ID:-}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo) repo=$2; shift 2 ;;
      --issue) issue=$2; shift 2 ;;
      --map) map=$2; shift 2 ;;
      --session) session=$2; shift 2 ;;
      *) break ;;
    esac
  done
  local note="$*"
  [ -n "$note" ] || die 'usage: atc jot [--issue N] [--map N] [--repo o/r] "note"'
  [ -n "$repo" ] || repo=$(repo_from_cwd 2>/dev/null || true)

  note=${note//$'\n'/ }
  local line="- $(now_hm)"
  [ -n "$repo" ] && line+=" repo=$repo"
  [ -n "$session" ] && line+=" session=$session"
  [ -n "$issue" ] && line+=" issue=#${issue#\#}"
  [ -n "$map" ] && line+=" map=#${map#\#}"
  line+=" :: $note"

  echo "$line" >>"$DATA_DIR/logs/$(today).jots.md"
  data_commit "jot $(today)"
  echo "Jotted: $line"
}

cmd_jots() { # [date]
  load_config
  local f="$DATA_DIR/logs/${1:-$(today)}.jots.md"
  [ -f "$f" ] && cat "$f" || true
}

cmd_projects() { load_config; tracked_repos; }

# GitHub contributions for one day, flagged tracked or not.
cmd_contributions() { # [date]
  load_config
  local d=${1:-$(today)} from to
  from=$(date -u -d "$d 00:00" +%FT%TZ)
  to=$(date -u -d "$d 23:59:59" +%FT%TZ)
  local q='query($login:String!,$from:DateTime!,$to:DateTime!){user(login:$login){contributionsCollection(from:$from,to:$to){
    commitContributionsByRepository(maxRepositories:100){repository{nameWithOwner} contributions(first:100){totalCount}}
    pullRequestContributions(first:100){nodes{pullRequest{number title url repository{nameWithOwner}}}}
    issueContributions(first:100){nodes{issue{number title url repository{nameWithOwner}}}}}}}'
  local tracked
  tracked=$(tracked_repos | jq -R . | jq -s .)
  gh api graphql -f query="$q" -f login="$OWNER" -f from="$from" -f to="$to" \
    | jq --argjson t "$tracked" '
      .data.user.contributionsCollection as $c
      | ( [$c.commitContributionsByRepository[] | {kind:"commits", repo:.repository.nameWithOwner, count:.contributions.totalCount}]
        + [$c.pullRequestContributions.nodes[] | .pullRequest | {kind:"pr", repo:.repository.nameWithOwner, number, title, url}]
        + [$c.issueContributions.nodes[] | .issue | {kind:"issue", repo:.repository.nameWithOwner, number, title, url}] )
      | map(. + {tracked: (.repo as $r | $t | index($r) != null)})'
}

# Write stdin to state/<repo>/<name>.md (no commit; run `atc save`).
cmd_state_write() { # repo name
  load_config
  [ $# -eq 2 ] || die "usage: atc state-write owner/repo name < file"
  local dir="$DATA_DIR/state/$(repo_slug "$1")"
  mkdir -p "$dir"
  cat >"$dir/$2.md"
  echo "wrote $dir/$2.md"
}

# Write stdin to logs/<date>.md, replacing that day's generated summary.
cmd_eod_write() { # [date]
  load_config
  cat >"$DATA_DIR/logs/${1:-$(today)}.md"
  echo "wrote logs/${1:-$(today)}.md"
}

cmd_save() { load_config; data_commit "${1:-atc update $(today)}"; }

last_eod_date() {
  local f
  f=$(ls "$DATA_DIR"/logs/????-??-??.md 2>/dev/null | tail -1 || true)
  if [ -n "$f" ]; then basename "$f" .md; else date -d "$(today) -7 days" +%F; fi
}

cmd_stale() { # [days]
  load_config
  local cutoff
  cutoff=$(date -d "$(today) -${1:-7} days" +%F)
  [ -f "$INDEX" ] && awk -F'\t' -v c="$cutoff" '$7=="open" && $5<c {print $1 "\t" $5 "\t" $6}' "$INDEX" || true
}

cmd_status() {
  load_config
  echo "Last EOD: $(last_eod_date)"
  local repo
  for repo in $(tracked_repos); do
    echo "== $repo"
    idx_keys_for_repo "$repo" | while read -r k; do idx_get "$k"; done \
      | awk -F'\t' '$7=="open" {c[$6]++} END {for (s in c) printf "  %s: %d\n", s, c[s]}' | sort
  done
  local s
  s=$(cmd_stale 7)
  [ -z "$s" ] || { echo "Untouched 7+ days:"; sed 's/^/  /' <<<"$s"; }
  return 0
}

# Raw material for the morning brief.
cmd_brief() {
  load_config
  local since repo
  since=$(last_eod_date)
  echo "# Brief data (since $since)"
  for repo in $(tracked_repos); do
    echo; echo "## $repo"
    echo "### Closed since $since"
    gh api "repos/$repo/issues?state=closed&since=${since}T00:00:00Z&per_page=50" \
      --jq '.[] | select(has("pull_request")|not) | select(.closed_at[:10] >= "'"$since"'") | "- #\(.number) \(.title) (closed \(.closed_at[:10]))"' 2>/dev/null || true
    echo "### Board cards"
    idx_keys_for_repo "$repo" | while read -r k; do
      awk -F'\t' '$7=="open" {print "- " $1 " [" $6 "]"}' <<<"$(idx_get "$k")"
    done
    echo "### State notes"
    local f
    for f in "$DATA_DIR/state/$(repo_slug "$repo")"/*.md; do
      [ -f "$f" ] && { echo "#### $(basename "$f")"; cat "$f"; }
    done
  done
  echo; echo "## Jots since $since"
  local jf
  for jf in "$DATA_DIR"/logs/????-??-??.jots.md; do
    [ -f "$jf" ] || continue
    [ "$(basename "$jf" .jots.md)" \< "$since" ] || { echo "### $(basename "$jf" .jots.md)"; cat "$jf"; }
  done
}
