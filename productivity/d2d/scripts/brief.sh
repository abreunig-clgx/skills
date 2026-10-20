# brief: raw facts for the morning brief (JSON, read-only)

# Open issues of a repo, one JSON array. Frontier first: not blocked, and either
# assigned to the user or labeled ready-for-*. Maps are listed apart, not here.
tickets_for_repo() { # repo me
  gh api "repos/$1/issues?state=open&per_page=100" --paginate | jq -s 'add // []' | jq -c --arg me "$2" '
    def canon: ["needs-triage","needs-info","ready-for-agent","ready-for-human","wontfix"];
    map(select(has("pull_request")|not)) as $all
    | ($all | map(select(.labels|map(.name)|index("wayfinder:map"))) | map({key:(.number|tostring), value:.title}) | from_entries) as $maps
    | [ $all[]
        | (.labels|map(.name)) as $l
        | select($l|index("wayfinder:map")|not)
        | ((.parent_issue_url // "") | split("/") | (last // "")) as $p
        | ([.assignees[].login]) as $as
        | ((.issue_dependencies_summary.blocked_by // 0) > 0) as $blocked
        | ($as|index($me) != null) as $mine
        | { number, title, url: .html_url, updated: .updated_at[:10], labels: $l,
            map: (if $maps[$p] then "#\($p) \($maps[$p])" else "" end),
            blocked: $blocked, mine: $mine, assignees: $as,
            triage: (([canon[] | select(. as $c | $l|index($c))]|.[0]) // $l[0] // "none"),
            frontier: ((($blocked|not)) and ($mine or ($l|any(startswith("ready-for-")))))} ]
    | sort_by([(if .frontier then 0 else 1 end), (if .mine then 0 else 1 end), .number])'
}

open_prs() { # repo
  gh api "repos/$1/pulls?state=open&per_page=100" --paginate | jq -sc 'add // [] | map({
    number, title, url: .html_url, draft, author: .user.login,
    closes: [(.body // "") | scan("(?i)(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?) #([0-9]+)") | .[0] | tonumber]})'
}

closed_since() { # repo since
  gh api "repos/$1/issues?state=closed&since=${2}T00:00:00Z&per_page=100" --paginate | jq -sc --arg s "$2" 'add // [] |
    map(select(has("pull_request")|not) | select(.closed_at[:10] >= $s)
      | {number, title, url: .html_url, closed: .closed_at[:10]})'
}

repo_state_text() { # repo
  local f
  for f in "$DATA_DIR/state/$(repo_slug "$1")"/*.md; do [ -f "$f" ] && cat "$f"; done
}

jots_since() { # since [repo]
  local f
  for f in "$DATA_DIR"/logs/????-??-??.jots.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f" .jots.md)" \< "$1" ] && continue
    if [ -n "${2:-}" ]; then grep -F -- "repo=$2 " "$f" || true; else cat "$f"; fi
  done | jq -R . | jq -sc .
}

# One JSON object: the last EOD summary, every tracked repo's facts, and recent jots.
cmd_brief() {
  load_config
  local since eod_file eod="" repo repos="[]" one
  since=$(last_eod_date)
  eod_file="$DATA_DIR/logs/$since.md"
  [ -f "$eod_file" ] && eod=$(cat "$eod_file")
  for repo in $(tracked_repos); do
    one=$(jq -n --arg repo "$repo" --arg since "$since" \
      --argjson maps "$(open_maps "$repo")" \
      --argjson open "$(tickets_for_repo "$repo" "$OWNER")" \
      --argjson closed "$(closed_since "$repo" "$since")" \
      --argjson prs "$(open_prs "$repo")" \
      --arg state "$(repo_state_text "$repo")" \
      '{repo:$repo, maps:$maps, open:$open, closed:$closed, prs:$prs, state:$state}')
    repos=$(jq -c --argjson o "$one" '. + [$o]' <<<"$repos")
  done
  jq -n --arg since "$since" --arg eod "$eod" --argjson repos "$repos" --argjson jots "$(jots_since "$since")" \
    '{since:$since, last_eod:$eod, repos:$repos, jots:$jots}'
}
