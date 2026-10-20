# detail: facts for one repo (JSON) and an HTML page from the written report.
# Used by /brief and /eod when the user wants more on a repo.

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
detail_since() { # repo session_day
  local day
  day=$( { last_jot_day "$1"; echo "$2"; } | grep . | sort | tail -1 || true)
  echo "${day:-$(date -d "$(today) -7 days" +%F)}"
}

api_list() { gh api "$1" --paginate | jq -s 'add // []'; }

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

# The top 3 open tickets (frontier first) with full detail.
top_tickets() { # repo prs_json
  local out="[]" row n
  while read -r row; do
    [ -n "$row" ] || continue
    n=$(jq -r .number <<<"$row")
    row=$(jq -c --argjson d "$(ticket_detail "$1" "$n" "$2")" '. + {detail:$d}' <<<"$row")
    out=$(jq -c --argjson r "$row" '. + [$r]' <<<"$out")
  done < <(tickets_for_repo "$1" "$OWNER" | jq -c '.[:3][]')
  echo "$out"
}

# Read-only. One JSON object for the repo.
cmd_detail() { # name [--since D] [--last-session D]
  load_config
  local name="" since="" session=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --since) since=$2; shift 2 ;;
      --last-session) session=$2; shift 2 ;;
      *) name=$1; shift ;;
    esac
  done
  [ -n "$name" ] || die "usage: d2d detail <repo> [--since D] [--last-session D]"
  local repo prs
  repo=$(resolve_repo "$name")
  [ -n "$since" ] || since=$(detail_since "$repo" "$session")
  prs=$(prs_since "$repo" "$since")
  jq -n --arg repo "$repo" --arg since "$since" \
    --argjson maps "$(open_maps "$repo")" --argjson closed "$(closed_since "$repo" "$since")" \
    --argjson prs "$prs" --argjson top "$(top_tickets "$repo" "$prs")" \
    --arg left "$(repo_state_text "$repo")" --argjson jots "$(jots_since "$since" "$repo")" '
    {repo:$repo, url:"https://github.com/\($repo)", since:$since, maps:$maps, closed:$closed,
     prs:$prs, top:$top, left_off:$left, jots:$jots}'
}

# Turn the written report (stdin, "## Heading" and text) into reports/<repo>-<date>.html
# in the data repo, by filling report-template.html. reports/ is gitignored.
cmd_html() { # name
  load_config
  [ $# -eq 1 ] || die "usage: d2d html <repo> < report.txt"
  local repo text out template="$HERE/../report-template.html" tmp
  [ -f "$template" ] || die "missing template: $template"
  repo=$(resolve_repo "$1")
  text=$(cat)
  [ -n "$text" ] || die "no report text on stdin"
  mkdir -p "$DATA_DIR/reports"
  out="$DATA_DIR/reports/$(repo_slug "$repo")-$(today).html"
  tmp=$(mktemp -d)
  html_body "$repo" <<<"$text" >"$tmp/body"
  progress_html "$repo" >"$tmp/progress"
  sed -e "s|{{REPO}}|$repo|g" \
    -e "/{{PROGRESS}}/{r $tmp/progress" -e d -e "}" \
    -e "/{{BODY}}/{r $tmp/body" -e d -e "}" "$template" >"$out"
  rm -rf "$tmp"
  echo "$out"
}

# Commit one report to the data repo, after the user agrees.
cmd_commit_report() { # path
  load_config
  [ -f "${1:-}" ] || die "usage: d2d commit-report <path to report html>"
  git -C "$DATA_DIR" add -f -- "$1"
  git -C "$DATA_DIR" commit -q -m "report $(basename "$1")"
  git -C "$DATA_DIR" push -q -u origin HEAD 2>/dev/null || echo "d2d: push failed; committed locally" >&2
  echo "Committed $(basename "$1")"
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
