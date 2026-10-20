#!/usr/bin/env bash
# Behavior tests for d2d. Runs the real `d2d` script against a fake `gh`.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D2D="$ROOT/productivity/d2d/scripts/d2d"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

export FAKE="$T/fake" D2D_POINTER="$T/pointer" DATA="$T/data"
unset D2D_HOME
export PATH="$ROOT/tests/fake-bin:$PATH"
export D2D_DATE=2026-10-16 D2D_TIME=09:30 COPILOT_AGENT_SESSION_ID=sess-1
export GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$FAKE/api"; echo org/a >"$FAKE/repos"; : >"$GIT_CONFIG_GLOBAL"

pass=0; fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok; else bad "$d"; fi; }
api() { echo "$2" >"$FAKE/api/$(sed 's|/|__|g' <<<"$1").json"; }

# --- setup ---
check "setup without a path asks for one" bash -c "'$D2D' setup 2>&1 | grep -q -- '--dir'"
out=$("$D2D" setup --dir "$DATA" 2>&1)
check "dry run changes nothing" test ! -f "$D2D_POINTER"
check "dry run says how to proceed" grep -q -- "--yes" <<<"$out"
check "commands refuse before setup" bash -c "! '$D2D' repos"

"$D2D" setup --dir "$DATA" --name my-private --yes >"$T/o" 2>&1
check "setup creates the private repo with the chosen name" grep -q "repo create me/my-private --private" "$FAKE/calls.log"
check "setup writes the pointer" test "$(cat "$D2D_POINTER")" = "$DATA"
check "setup stores settings in the repo" jq -e '.repo=="my-private" and .owner=="me" and .tracked==[]' "$DATA/d2d.json"
check "setup ignores reports" grep -qx 'reports/' "$DATA/.gitignore"
check "setup pushes d2d.json" git --git-dir="$FAKE/remote.git" show main:d2d.json
check "setup never touches projects" bash -c "! grep -q project '$FAKE/calls.log'"
"$D2D" setup --yes >/dev/null 2>&1
check "setup is idempotent" test "$(grep -c 'repo create' "$FAKE/calls.log")" = 1

# --- a wiped machine: the repo is reused, tracked repos survive ---
"$D2D" add org/a >/dev/null 2>&1
rm -rf "$DATA" "$D2D_POINTER"
"$D2D" setup --dir "$DATA" --name my-private --yes >/dev/null 2>&1
check "re-setup reuses the existing repo" test "$(grep -c 'repo create' "$FAKE/calls.log")" = 1
check "tracked repos survive a wipe" bash -c "'$D2D' repos | grep -qx org/a"

# --- add / remove ---
"$D2D" add org/a >/dev/null 2>&1
check "add tracks repo once" test "$("$D2D" repos | grep -c '^org/a$')" = 1
check "add refuses unreachable repo" bash -c "! '$D2D' add noaccess/x"
check "add refuses repo without issues" bash -c "! '$D2D' add noissues/x"
check "add rejects bad format" bash -c "! '$D2D' add justname"
check "add with different case tracks once" bash -c "'$D2D' add org/A && test \$('$D2D' repos | grep -ci '^org/a\$') = 1"
check "add shows labels" bash -c "'$D2D' add org/a | grep -q ready-for-agent"
"$D2D" add org/b >/dev/null 2>&1
"$D2D" remove org/b >/dev/null 2>&1
check "remove stops tracking" bash -c "! '$D2D' repos | grep -q org/b"
check "remove of untracked repo fails" bash -c "! '$D2D' remove org/b"

# --- jot ---
mkdir -p "$T/work" && git -C "$T/work" init -q && git -C "$T/work" remote add origin git@github.com:org/a.git
(cd "$T/work" && "$D2D" jot "remember the retry logic" >/dev/null)
(cd "$T/work" && "$D2D" jot --issue 12 --map "#3" "tagged note" >/dev/null)
(cd "$T" && "$D2D" jot "no repo here" >/dev/null)
J="$DATA/logs/2026-10-16.jots.md"
check "jot records repo, session, text" grep -q -- '^- 09:30 repo=org/a session=sess-1 :: remember the retry logic$' "$J"
check "jot records issue and map tags" grep -q -- 'issue=#12 map=#3 :: tagged note' "$J"
check "jot works outside a repo" grep -q -- '^- 09:30 session=sess-1 :: no repo here$' "$J"
check "jot is append-only (3 lines)" test "$(wc -l <"$J")" = 3
check "jot is pushed" git --git-dir="$FAKE/remote.git" show main:logs/2026-10-16.jots.md

# --- eod writes ---
"$D2D" state-write org/a map-1 <<<"## #2 Research
Left off: compared two tile schemes" >/dev/null
"$D2D" eod-write >/dev/null <<<"# EOD"
"$D2D" eod-write >/dev/null <<<"# EOD v2"
check "eod-write replaces the day's summary" test "$(cat "$DATA/logs/2026-10-16.md")" = "# EOD v2"
check "eod-write leaves jots alone" test "$(wc -l <"$J")" = 3
"$D2D" publish >/dev/null 2>&1
check "publish pushes state notes" git --git-dir="$FAKE/remote.git" show main:state/org__a/map-1.md

# --- brief ---
cat >"$FAKE/issues_open_org__a.json" <<'JSON'
[
 {"number":1,"title":"Map: parcels","html_url":"u/1","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:map"}],"assignees":[],"sub_issues_summary":{"total":4,"completed":1}},
 {"number":2,"title":"Research tiles","html_url":"u/2","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"ready-for-agent"}],"assignees":[],"parent_issue_url":"https://api.github.com/repos/org/a/issues/1"},
 {"number":3,"title":"Blocked one","html_url":"u/3","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"ready-for-agent"}],"assignees":[],"issue_dependencies_summary":{"blocked_by":1}},
 {"number":4,"title":"Someone elses","html_url":"u/4","updated_at":"2026-10-15T10:00:00Z","labels":[],"assignees":[{"login":"other"}]},
 {"number":5,"title":"Mine in flight","html_url":"u/5","updated_at":"2026-10-15T10:00:00Z","labels":[],"assignees":[{"login":"me"}]},
 {"number":6,"title":"A PR","html_url":"u/6","updated_at":"2026-10-15T10:00:00Z","labels":[],"assignees":[],"pull_request":{}},
 {"number":9,"title":"Plain untriaged","html_url":"u/9","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"bug"}],"assignees":[]}
]
JSON
echo '[{"number":20,"title":"Old thing","html_url":"u/20","closed_at":"2026-10-16T12:00:00Z"},
      {"number":21,"title":"Older thing","html_url":"u/21","closed_at":"2026-10-01T12:00:00Z"},
      {"number":22,"title":"A PR","html_url":"u/22","closed_at":"2026-10-16T12:00:00Z","pull_request":{}}]' >"$FAKE/issues_closed_org__a.json"
api "repos/org/a/pulls?state=open&per_page=100" '[{"number":30,"title":"Add tiles","html_url":"p/30","draft":false,"user":{"login":"me"},"body":"Closes #2 and fixes #5"}]'

B="$T/brief.json"
"$D2D" brief >"$B" 2>"$T/err"
check "brief is valid JSON" jq -e . "$B"
check "brief carries the last EOD summary" jq -e '.last_eod=="# EOD v2"' "$B"
check "brief lists every open ticket, not just maps" jq -e '.repos[0].open | map(.number) | sort == [2,3,4,5,9]' "$B"
check "brief leaves maps apart with progress" jq -e '.repos[0].maps[0] | .number==1 and .done==1 and .total==4' "$B"
check "frontier: unblocked and ready or mine" jq -e '.repos[0].open | map(select(.frontier).number) | sort == [2,5]' "$B"
check "frontier comes first, mine before others" jq -e '.repos[0].open | .[0].number==5 and .[1].number==2' "$B"
check "blocked ticket is flagged" jq -e '.repos[0].open[] | select(.number==3) | .blocked' "$B"
check "ticket knows its map" jq -e '.repos[0].open[] | select(.number==2) | .map=="#1 Map: parcels"' "$B"
check "brief shows closed issues since last EOD, no PRs" jq -e '.repos[0].closed | map(.number)==[20]' "$B"
check "brief shows open PRs with the tickets they close" jq -e '.repos[0].prs[0] | .number==30 and .closes==[2,5]' "$B"
check "brief shows state notes" jq -e '.repos[0].state | contains("compared two tile schemes")' "$B"
check "brief shows jots since last EOD" jq -e '.jots | any(contains("retry logic"))' "$B"
check "brief writes nothing" test -z "$(git -C "$DATA" status --porcelain)"

# --- detail and html ---
api "repos/org/a/pulls?state=all&sort=updated&direction=desc&per_page=100&page=1" '[
 {"number":30,"title":"Add tiles","html_url":"p/30","state":"open","merged_at":null,"updated_at":"2026-10-15T09:00:00Z","body":"Closes #2"},
 {"number":32,"title":"Ancient","html_url":"p/32","state":"closed","merged_at":null,"updated_at":"2026-09-01T09:00:00Z","body":""}]'
for n in 2 3 4 5 9; do
  api "repos/org/a/issues/$n" "{\"number\":$n,\"body\":\"Body $n\"}"
  api "repos/org/a/issues/$n/comments?per_page=100" "[{\"user\":{\"login\":\"bob\"},\"body\":\"Decision for $n\"}]"
  api "repos/org/a/issues/$n/timeline?per_page=100" '[]'
done
"$D2D" detail a --since 2026-10-10 >"$T/d.json" 2>"$T/err"
check "detail resolves a short name" jq -e '.repo=="org/a"' "$T/d.json"
check "detail covers recent PRs only" jq -e '.prs | map(.number)==[30]' "$T/d.json"
check "detail gives the top 3 tickets in depth" jq -e '.top | length==3 and (.[0].detail.comments[0]|contains("Decision"))' "$T/d.json"
check "detail ties PRs to tickets" jq -e '.top[] | select(.number==2) | .detail.prs==[30]' "$T/d.json"
check "detail untracked repo fails" bash -c "! '$D2D' detail nope/x"

printf '## Goal\nBuild #2 via PR #30\n- one\n- two\n' | "$D2D" html a >"$T/path" 2>"$T/err"
P=$(cat "$T/path")
check "html lands in the data repo reports dir" test "$P" = "$DATA/reports/org__a-2026-10-16.html"
check "html links tickets and PRs" bash -c "grep -q 'org/a/pull/30' '$P' && grep -q 'org/a/issues/2' '$P'"
check "html shows map progress" grep -q 'Map #1: 1/4' "$P"
check "html is not committed by default" test -z "$(git -C "$DATA" status --porcelain)"
"$D2D" commit-report "$P" >/dev/null 2>&1
check "commit-report commits it on request" git --git-dir="$FAKE/remote.git" show main:reports/org__a-2026-10-16.html

# --- no leftovers of the old name ---
old="a""tc"
check "no old-name strings anywhere" bash -c "! grep -rniwE '$old|$old-[a-z]+|\\.$old' '$ROOT' --exclude-dir=.git | grep -q ."

echo "passed: $pass, failed: $fail"
[ "$fail" = 0 ]
