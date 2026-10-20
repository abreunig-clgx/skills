# jot, jots, contributions, and the write helpers used by /eod

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
  [ -n "$note" ] || die 'usage: d2d jot [--issue N] [--map N] [--repo o/r] "note"'
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

cmd_repos() { load_config; tracked_repos; }

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

# Write stdin to state/<repo>/<name>.md (no commit; `d2d publish` commits).
cmd_state_write() { # repo name
  load_config
  [ $# -eq 2 ] || die "usage: d2d state-write owner/repo name < file"
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

cmd_publish() {
  load_config
  data_commit "d2d update $(today)"
  echo "Published to $OWNER/$DATA_REPO"
}

last_eod_date() {
  local f
  f=$(ls "$DATA_DIR"/logs/????-??-??.md 2>/dev/null | tail -1 || true)
  if [ -n "$f" ]; then basename "$f" .md; else date -d "$(today) -7 days" +%F; fi
}
