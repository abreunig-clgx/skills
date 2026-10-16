#!/usr/bin/env bash
# Behavior tests for `atc report-data` and `atc report-html`. Real atc, fake gh.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ATC="$ROOT/productivity/atc/scripts/atc"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

export FAKE="$T/fake" ATC_CONFIG="$T/config.env" ATC_DATA_DIR="$T/data"
export PATH="$ROOT/tests/fake-bin:$PATH" ATC_DATE=2026-10-16 ATC_TIME=09:30
mkdir -p "$FAKE/api" "$ATC_DATA_DIR/logs" "$ATC_DATA_DIR/state/org__alpha"
printf 'OWNER=me\nDATA_REPO=me-atc\nDATA_DIR=%s\nPROJECT_NUMBER=7\n' "$ATC_DATA_DIR" >"$ATC_CONFIG"
printf 'org/alpha\norg/beta\nother/beta\n' >"$ATC_DATA_DIR/projects.txt"

pass=0; fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok; else bad "$d"; fi; }

api() { echo "$2" >"$FAKE/api/$(sed 's|/|__|g' <<<"$1").json"; }

# --- fixtures for org/alpha ---
cat >"$FAKE/issues_open_org__alpha.json" <<'JSON'
[
 {"number":1,"title":"Map: parcels","html_url":"https://x/1","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:map"}],"assignees":[],"sub_issues_summary":{"total":6,"completed":2}},
 {"number":2,"title":"T2","html_url":"https://x/2","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:task"}],"assignees":[],"parent_issue_url":"https://api.github.com/repos/org/alpha/issues/1"},
 {"number":3,"title":"T3","html_url":"https://x/3","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:task"}],"assignees":[],"parent_issue_url":"https://api.github.com/repos/org/alpha/issues/1"},
 {"number":4,"title":"T4","html_url":"https://x/4","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:task"}],"assignees":[],"parent_issue_url":"https://api.github.com/repos/org/alpha/issues/1"},
 {"number":5,"title":"T5","html_url":"https://x/5","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:task"}],"assignees":[],"parent_issue_url":"https://api.github.com/repos/org/alpha/issues/1"},
 {"number":6,"title":"Loose bug","html_url":"https://x/6","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"ready-for-human"}],"assignees":[]},
 {"number":7,"title":"Fuzzy idea","html_url":"https://x/7","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"needs-info"}],"assignees":[]}
]
JSON
echo '[{"number":20,"title":"Old thing","html_url":"https://x/20","closed_at":"2026-10-14T12:00:00Z"},
      {"number":21,"title":"Older thing","html_url":"https://x/21","closed_at":"2026-10-01T12:00:00Z"},
      {"number":22,"title":"A PR","html_url":"https://x/22","closed_at":"2026-10-14T12:00:00Z","pull_request":{}}]' >"$FAKE/issues_closed_org__alpha.json"
api "repos/org/alpha/pulls?state=all&sort=updated&direction=desc&per_page=30" '[
 {"number":30,"title":"Add tiles","html_url":"https://x/30","state":"closed","merged_at":"2026-10-14T09:00:00Z","updated_at":"2026-10-14T09:00:00Z","body":"Closes #2 and fixes #3"},
 {"number":31,"title":"Wip","html_url":"https://x/31","state":"open","merged_at":null,"updated_at":"2026-10-15T09:00:00Z","body":null},
 {"number":32,"title":"Ancient","html_url":"https://x/32","state":"closed","merged_at":null,"updated_at":"2026-09-01T09:00:00Z","body":""}]'
api "repos/org/alpha/issues/1" '{"number":1,"title":"Map: parcels","body":"Goal of the map","html_url":"https://x/1"}'
for n in 2 3 4 5 6; do
  api "repos/org/alpha/issues/$n" "{\"number\":$n,\"title\":\"T$n\",\"body\":\"Body $n\",\"html_url\":\"https://x/$n\"}"
  api "repos/org/alpha/issues/$n/comments?per_page=100" "[{\"user\":{\"login\":\"bob\"},\"body\":\"Decision for $n\"}]"
  api "repos/org/alpha/issues/$n/timeline?per_page=100" '[]'
done
api "repos/org/alpha/issues/4/timeline?per_page=100" '[{"event":"cross-referenced","source":{"issue":{"number":31,"pull_request":{}}}},{"event":"cross-referenced","source":{"issue":{"number":99}}}]'
echo "- 08:00 repo=org/alpha session=s1 :: jotted today" >"$ATC_DATA_DIR/logs/2026-10-15.jots.md"
printf '# Map\n## #2 T2\nLeft off: halfway.\n' >"$ATC_DATA_DIR/state/org__alpha/map-1.md"

data() { "$ATC" report-data "$@" 2>&1; }

# --- repo resolution ---
check "short name resolves" bash -c "'$ATC' report-data alpha | jq -e '.repo==\"org/alpha\"'"
check "full name resolves" bash -c "'$ATC' report-data org/alpha | jq -e '.repo==\"org/alpha\"'"
check "ambiguous short name is an error" bash -c "! '$ATC' report-data beta"
check "ambiguous error names the candidates" grep -q "org/beta" <<<"$(data beta)"
check "untracked repo is an error" bash -c "! '$ATC' report-data nope/x"
check "unknown short name is an error" bash -c "! '$ATC' report-data zzz"

D=$("$ATC" report-data alpha 2>&1)
j() { jq -e "$1" <<<"$D"; }

# --- last touched ---
check "last touched is the newest jot for the repo" j '.since=="2026-10-15"'
D=$("$ATC" report-data alpha --last-session 2026-10-16 2>&1)
check "a newer session wins" j '.since=="2026-10-16"'
rm "$ATC_DATA_DIR/logs/2026-10-15.jots.md"
D=$("$ATC" report-data alpha 2>&1)
check "fallback is 7 days" j '.since=="2026-10-09"'
echo "- 08:00 repo=org/alpha session=s1 :: jotted today" >"$ATC_DATA_DIR/logs/2026-10-15.jots.md"
D=$("$ATC" report-data alpha --since 2026-10-09 2>&1)

# --- goal, since, frontier ---
check "goal has map progress" j '.maps[0] | .number==1 and .done==2 and .total==6'
check "goal carries map body" j '.maps[0].body=="Goal of the map"'
check "closed issues since, no PRs, no old ones" j '[.closed[].number]==[20]'
check "recent PRs only" j '[.prs[].number]==[30,31]'
check "PR keeps its state" j '.prs[0].state=="merged" and .prs[1].state=="open"'
check "PR closing links parsed" j '.prs[0].closes==[2,3]'
check "frontier excludes maps" j '[.frontier[].number] | index(1) == null'
check "top 3 are detailed, rest are not" j '([.frontier[]|select(.detail)]|length)==3 and ([.frontier[]|select(.detail|not)]|length)>=1'
check "detailed ticket has body" j '.frontier[0].detail.body|startswith("Body")'
check "detailed ticket has all comments" j '.frontier[0].detail.comments[0]|contains("Decision for")'
check "loose ticket has no map" j '[.frontier[]|select(.number==6)][0].map==""'
check "ticket knows its map" j '[.frontier[]|select(.number==2)][0].map|startswith("#1")'
check "timeline PR is tied to the ticket" j '[.frontier[]|select(.number==4)][0].detail.prs|index(31)!=null'
check "closing PR is tied to the ticket" j '[.frontier[]|select(.number==2)][0].detail.prs|index(30)!=null'
check "foggy lists needs-info issues, max 3" j '[.foggy[].number]==[7]'
check "left off has state note text" j '.left_off|contains("Left off: halfway.")'
check "jots since last touch are included" j '.jots|length==1'
check "links use the repo url" j '.url=="https://github.com/org/alpha"'
check "report-data never writes" test "$(ls "$T" | grep -c atc-report)" = 0
check "report-data never edits issues" bash -c "! grep -E 'issue (edit|create|close)|--method (POST|PATCH)' '$FAKE/calls.log'"

# --- html ---
mkdir -p "$T/out"
printf '## Goal\nShip parcels <fast> & well. See #2 and PR #30.\n\n## Next\n- #4 do it\n' \
  | (cd "$T/out" && "$ATC" report-html alpha) >"$T/o" 2>&1
H="$T/out/atc-report-alpha.html"
check "html file written in cwd" test -f "$H"
check "html path is printed" grep -q "atc-report-alpha.html" "$T/o"
check "html is escaped" grep -q 'Ship parcels &lt;fast&gt; &amp; well' "$H"
check "html links ticket numbers" grep -q 'href="https://github.com/org/alpha/issues/2"' "$H"
check "html is self-contained" bash -c "! grep -Ei 'src=|<link ' '$H'"
check "html headings" grep -q '<h2>Goal</h2>' "$H"
printf '## Again\nx\n' | (cd "$T/out" && "$ATC" report-html alpha) >/dev/null 2>&1
check "html is overwritten each run" bash -c "grep -q Again '$H' && ! grep -q Goal '$H'"
check "html needs text on stdin" bash -c "cd '$T/out' && ! '$ATC' report-html alpha </dev/null"

echo "report tests passed: $pass, failed: $fail"
[ "$fail" = 0 ]
