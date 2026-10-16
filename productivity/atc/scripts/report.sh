# report: facts for one repo (JSON), and an HTML page from the written report.

# Full name from a full or short name. Short names must match exactly one tracked repo.
resolve_repo() { # name
  local name=$1 hits
  if [[ "$name" == */* ]]; then
    tracked_repos | grep -Fxq "$name" || die "$name is not tracked"
    echo "$name"; return
  fi
  hits=$(tracked_repos | awk -F/ -v n="$name" '$2==n')
  case $(grep -c . <<<"$hits") in
    1) echo "$hits" ;;
    0) die "no tracked repo named '$name'" ;;
    *) die "'$name' is ambiguous: $(tr '\n' ' ' <<<"$hits")" ;;
  esac
}

# Newest day with a jot for this repo, or empty.
last_jot_day() { # repo
  grep -l -- "repo=$1 " "$DATA_DIR"/logs/????-??-??.jots.md 2>/dev/null | sed 's|.*/||; s|\.jots\.md||' | sort | tail -1 || true
}

# Last touched: newest of a session day and a jot day. Fallback: 7 days.
report_since() { # repo session_day
  local day
  day=$( { last_jot_day "$1"; echo "$2"; } | grep . | sort | tail -1 || true)
  echo "${day:-$(date -d "$(today) -7 days" +%F)}"
}

api_list() { gh api "$1" --paginate | jq -s 'add // []'; }

closed_since() { # repo since
  api_list "repos/$1/issues?state=closed&since=${2}T00:00:00Z&per_page=100" | jq -c --arg s "$2" '
    map(select(has("pull_request")|not) | select(.closed_at[:10] >= $s)
      | {number, title, url: .html_url, closed: .closed_at[:10]})'
}

# Newest first, 100 per page; keep paging until a page reaches back before $since.
prs_since() { # repo since
  local page=1 got all="[]"
  while :; do
    got=$(gh api "repos/$1/pulls?state=all&sort=updated&direction=desc&per_page=100&page=$page")
    all=$(jq -c --argjson g "$got" '. + $g' <<<"$all")
    jq -e --arg s "$2" 'length==100 and (last.updated_at[:10] >= $s)' <<<"$got" >/dev/null || break
    page=$((page + 1))
  done
  jq -c --arg s "$2" '
    map(select(.updated_at[:10] >= $s) | {
      number, title, url: .html_url,
      state: (if .merged_at then "merged" else .state end),
      summary: ((.body // "") | gsub("[\\r\\n]+"; " ") | gsub("#+ |[*`>]"; "") | gsub("^ +| +$"; "") | .[:200]),
      closes: [(.body // "") | scan("(?i)(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?) #([0-9]+)") | .[0] | tonumber]})' <<<"$all"
}

# Everything we know about one ticket: body, every comment, tied PRs.
ticket_detail() { # repo number prs_json
  local repo=$1 n=$2 issue comments tl
  issue=$(gh api "repos/$repo/issues/$n")
  comments=$(api_list "repos/$repo/issues/$n/comments?per_page=100")
  tl=$(api_list "repos/$repo/issues/$n/timeline?per_page=100")
  jq -n --argjson i "$issue" --argjson c "$comments" --argjson t "$tl" --argjson prs "$3" --argjson n "$n" '
    {body: ($i.body // ""),
     comments: ($c | map("\(.user.login): \(.body)")),
     prs: ( [$t[] | select(.event=="cross-referenced") | .source.issue | select(.pull_request) | .number]
          + [$prs[] | select(.closes | index($n)) | .number] | unique)}'
}

# Open work, in order: in progress, next up, blocked, inbox. Loose issues have map "". Top 3 get detail.
frontier() { # repo prs_json
  local rows n out="[]" row i=0
  rows=$(cards_for_repo "$1" "$OWNER" | jq -sc '
    map(select(.stage|IN("In progress","Next up","Blocked","Inbox")))
    | sort_by(.stage | {"In progress":0,"Next up":1,"Blocked":2,"Inbox":3}[.]) | map({number, title, url, stage, map, triage})')
  while read -r row; do
    [ -n "$row" ] || continue
    n=$(jq -r .number <<<"$row")
    if [ "$i" -lt 3 ]; then row=$(jq -c --argjson d "$(ticket_detail "$1" "$n" "$2")" '. + {detail:$d}' <<<"$row"); fi
    out=$(jq -c --argjson r "$row" '. + [$r]' <<<"$out"); i=$((i + 1))
  done < <(jq -c '.[]' <<<"$rows")
  echo "$out"
}

foggy() { # repo
  cards_for_repo "$1" "$OWNER" | jq -sc 'map(select(.triage=="needs-info" or .triage=="needs-triage")) | .[:3] | map({number, title, url})'
}

repo_state_text() { # repo
  local f
  for f in "$DATA_DIR/state/$(repo_slug "$1")"/*.md; do [ -f "$f" ] && cat "$f"; done
}

jots_since() { # repo since
  local f
  for f in "$DATA_DIR"/logs/????-??-??.jots.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f" .jots.md)" \< "$2" ] || grep -F -- "repo=$1 " "$f" || true
  done | jq -R . | jq -sc .
}

# Read-only. Prints one JSON object for the repo report.
cmd_report_data() { # name [--since D] [--last-session D]
  load_config
  local name="" since="" session=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --since) since=$2; shift 2 ;;
      --last-session) session=$2; shift 2 ;;
      *) name=$1; shift ;;
    esac
  done
  [ -n "$name" ] || die "usage: atc report-data <repo> [--since D] [--last-session D]"
  local repo prs
  repo=$(resolve_repo "$name")
  [ -n "$since" ] || since=$(report_since "$repo" "$session")
  prs=$(prs_since "$repo" "$since")
  jq -n --arg repo "$repo" --arg since "$since" \
    --argjson maps "$(open_maps "$repo")" --argjson closed "$(closed_since "$repo" "$since")" \
    --argjson prs "$prs" --argjson frontier "$(frontier "$repo" "$prs")" \
    --argjson foggy "$(foggy "$repo")" --arg left "$(repo_state_text "$repo")" \
    --argjson jots "$(jots_since "$repo" "$since")" '
    {repo:$repo, url:"https://github.com/\($repo)", since:$since, maps:$maps, closed:$closed,
     prs:$prs, frontier:$frontier, foggy:$foggy, left_off:$left, jots:$jots}'
}

# Turn the written report (stdin, "## Heading" and text) into one HTML file in the cwd,
# by filling the shipped report-template.html.
cmd_report_html() { # name
  load_config
  [ $# -eq 1 ] || die "usage: atc report-html <repo> < report.txt"
  local repo text out template="$HERE/../../atc-report/report-template.html" tmp
  [ -f "$template" ] || die "missing template: $template"
  repo=$(resolve_repo "$1")
  text=$(cat)
  [ -n "$text" ] || die "no report text on stdin"
  out="atc-report-${repo#*/}.html"
  tmp=$(mktemp -d)
  html_body "$repo" <<<"$text" >"$tmp/body"
  progress_html "$repo" >"$tmp/progress"
  sed -e "s|{{REPO}}|$repo|g" \
    -e "/{{PROGRESS}}/{r $tmp/progress" -e d -e "}" \
    -e "/{{BODY}}/{r $tmp/body" -e d -e "}" "$template" >"$out"
  rm -rf "$tmp"
  echo "$PWD/$out"
}

# One progress bar per open map.
progress_html() { # repo
  open_maps "$1" | jq -r '.[] | (if .total > 0 then (.done * 100 / .total | floor) else 0 end) as $pct
    | "<div class=\"map\">Map #\(.number): \(.done)/\(.total) done<div class=\"bar\"><span style=\"width:\($pct)%\"></span></div></div>"' \
    | sed 's/&/\&amp;/g'
}

# Escape, link refs, mark up headings and bullets, then wrap bullets in <ul>.
html_body() { # repo; text on stdin
  local base="https://github.com/$1"
  sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
    -e "s|\(PR \)#\([0-9][0-9]*\)|\1<a href=\"$base/pull/\2\">#\2</a>|g" \
    -e "s|\([^\">/0-9A-Za-z]\)#\([0-9][0-9]*\)|\1<a href=\"$base/issues/\2\">#\2</a>|g" \
    -e "s|^#\([0-9][0-9]*\)|<a href=\"$base/issues/\1\">#\1</a>|" \
    -e "s|^## \(.*\)\$|<h2>\1</h2>|" \
    -e "s|^- \(.*\)\$|<li>\1</li>|" \
    -e 's|^$|<br>|' \
  | awk '/^<li>/ { if (!u) print "<ul>"; u = 1 }
         !/^<li>/ && u { print "</ul>"; u = 0 }
         { print }
         END { if (u) print "</ul>" }'
}
