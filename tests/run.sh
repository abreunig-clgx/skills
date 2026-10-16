#!/usr/bin/env bash
# Behavior tests for atc. Runs the real `atc` script against a fake `gh`.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ATC="$ROOT/productivity/atc/scripts/atc"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

export FAKE="$T/fake" ATC_CONFIG="$T/config.env" ATC_DATA_DIR="$T/data"
export PATH="$ROOT/tests/fake-bin:$PATH"
export ATC_DATE=2026-10-16 ATC_TIME=09:30 COPILOT_AGENT_SESSION_ID=sess-1
export GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$FAKE"; echo org/a >"$FAKE/repos"; : >"$GIT_CONFIG_GLOBAL"

pass=0; fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }
check() { # description command...
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then ok; else bad "$d"; fi
}
calls() { grep -c -- "$1" "$FAKE/calls.log" 2>/dev/null || true; }
idx() { awk -F'\t' -v k="$1" -v c="$2" '$1==k {print $c}' "$ATC_DATA_DIR/index.tsv"; }

# --- setup ---
out=$("$ATC" setup 2>&1)
check "setup without --yes changes nothing" test ! -f "$ATC_CONFIG"
check "setup without --yes says how to proceed" grep -q -- "--yes" <<<"$out"

FAKE_NO_PROJECT_SCOPE=1 "$ATC" setup --yes >"$T/o" 2>&1
check "setup stops without project scope" grep -q "gh auth refresh -s project" "$T/o"
check "setup without scope creates nothing" test ! -f "$ATC_CONFIG"

"$ATC" setup --yes >"$T/o" 2>&1
check "setup writes config" grep -q "PROJECT_NUMBER=7" "$ATC_CONFIG"
check "setup creates private data repo" grep -q "repo create me/me-atc --private" "$FAKE/calls.log"
for f in Stage "Source repo" Triage Map "Wayfinder type" "Last touched"; do
  check "setup creates field $f" jq -e --arg f "$f" 'map(select(.name==$f))|length==1' "$FAKE/fields.json"
done
check "setup pushes seed files" git --git-dir="$FAKE/remote.git" show main:projects.txt
out=$("$ATC" setup --yes 2>&1)
check "setup never creates a Repo field" jq -e 'map(select(.name=="Repo"))|length==0' "$FAKE/fields.json"
check "setup prints the view checklist" grep -q "Group by: Source repo" <<<"$out"
check "setup is idempotent (one project)" test "$(calls 'project create')" = 1
check "setup is idempotent (no duplicate fields)" jq -e 'length==6' "$FAKE/fields.json"

# --- add / remove ---
"$ATC" add org/a >/dev/null 2>&1
"$ATC" add org/a >/dev/null 2>&1
check "add tracks repo once" test "$(grep -c '^org/a$' "$ATC_DATA_DIR/projects.txt")" = 1
check "add refuses unreachable repo" bash -c "! '$ATC' add noaccess/x"
check "add refuses repo without issues" bash -c "! '$ATC' add noissues/x"
check "add rejects bad format" bash -c "! '$ATC' add justname"
check "add syncs the new repo" test "$(calls 'repos/org/a/issues')" -gt 0
check "add with different case does not die" bash -c "'$ATC' add org/A"
check "add with different case tracks once" test "$(grep -ci '^org/a$' "$ATC_DATA_DIR/projects.txt")" = 1
check "add shows labels" bash -c "'$ATC' add org/a | grep -q ready-for-agent"

# --- jot ---
mkdir -p "$T/work" && git -C "$T/work" init -q && git -C "$T/work" remote add origin git@github.com:org/a.git
(cd "$T/work" && "$ATC" jot "remember the retry logic" >/dev/null)
(cd "$T/work" && "$ATC" jot --issue 12 --map "#3" "tagged note" >/dev/null)
(cd "$T" && "$ATC" jot "no repo here" >/dev/null)
J="$ATC_DATA_DIR/logs/2026-10-16.jots.md"
check "jot records repo, session, text" grep -q -- '^- 09:30 repo=org/a session=sess-1 :: remember the retry logic$' "$J"
check "jot records issue and map tags" grep -q -- 'issue=#12 map=#3 :: tagged note' "$J"
check "jot works outside a repo" grep -q -- '^- 09:30 session=sess-1 :: no repo here$' "$J"
check "jot is append-only (3 lines)" test "$(wc -l <"$J")" = 3
check "jot is pushed" git --git-dir="$FAKE/remote.git" show main:logs/2026-10-16.jots.md
check "jots prints the day" bash -c "'$ATC' jots | grep -q retry"

# --- sync ---
cat >"$FAKE/issues_open_org__a.json" <<'JSON'
[
 {"number":1,"title":"Map: parcels","html_url":"u/1","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:map"}],"assignees":[],"sub_issues_summary":{"total":4,"completed":1}},
 {"number":2,"title":"Research tiles","html_url":"u/2","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:research"}],"assignees":[],"parent_issue_url":"https://api.github.com/repos/org/a/issues/1","issue_dependencies_summary":{"blocked_by":0}},
 {"number":3,"title":"Blocked one","html_url":"u/3","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:task"}],"assignees":[],"parent_issue_url":"https://api.github.com/repos/org/a/issues/1","issue_dependencies_summary":{"blocked_by":1}},
 {"number":4,"title":"Someone elses","html_url":"u/4","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:task"}],"assignees":[{"login":"other"}],"parent_issue_url":"https://api.github.com/repos/org/a/issues/1"},
 {"number":5,"title":"Mine in flight","html_url":"u/5","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wayfinder:task"}],"assignees":[{"login":"me"}],"parent_issue_url":"https://api.github.com/repos/org/a/issues/1","issue_dependencies_summary":{"blocked_by":1}},
 {"number":6,"title":"Loose ticket","html_url":"u/6","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"ready-for-human"}],"assignees":[{"login":"other"}]},
 {"number":7,"title":"Won't fix","html_url":"u/7","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"wontfix"}],"assignees":[]},
 {"number":8,"title":"A PR","html_url":"u/8","updated_at":"2026-10-15T10:00:00Z","labels":[],"assignees":[],"pull_request":{}},
 {"number":9,"title":"Plain untriaged","html_url":"u/9","updated_at":"2026-10-15T10:00:00Z","labels":[{"name":"bug"}],"assignees":[]}
]
JSON

"$ATC" sync --dry-run >"$T/o" 2>&1
check "dry run reports new cards" grep -q "5 new" "$T/o"
check "dry run creates nothing" test "$(calls 'issue create')" = 0

"$ATC" sync >"$T/o" 2>&1
check "sync creates 5 cards" grep -q "5 new" "$T/o"
check "map issue is not a card" test -z "$(idx 'org/a#1' 1)"
check "frontier child is a card, Next up" test "$(idx 'org/a#2' 6)" = "Next up"
check "blocked child is hidden" test -z "$(idx 'org/a#3' 1)"
check "child assigned to someone else is hidden" test -z "$(idx 'org/a#4' 1)"
check "my blocked ticket shows as Blocked" test "$(idx 'org/a#5' 6)" = Blocked
check "loose ticket shows even if assigned elsewhere" test "$(idx 'org/a#6' 6)" = "Next up"
check "wontfix goes to Stale" test "$(idx 'org/a#7' 6)" = Stale
check "pull requests are skipped" test -z "$(idx 'org/a#8' 1)"
check "untriaged loose issue goes to Inbox" test "$(idx 'org/a#9' 6)" = Inbox
check "card title is the ticket title only" grep -q 'issue create -R me/me-atc --title Research tiles --body' "$FAKE/calls.log"
check "triage field uses canonical label" grep -q 'item-edit .*--text ready-for-human' "$FAKE/calls.log"
check "map name set on child" grep -q -- '--text #1 Map: parcels' "$FAKE/calls.log"
check "source repo field is set" grep -q -- '--text org/a' "$FAKE/calls.log"
check "sync commits index" git --git-dir="$FAKE/remote.git" show main:index.tsv

before=$(calls 'issue create')
"$ATC" sync >"$T/o" 2>&1
check "second sync changes nothing" grep -q "0 new, 0 updated, 0 done, 0 hidden" "$T/o"
check "second sync creates no stubs" test "$(calls 'issue create')" = "$before"

# state notes flow into the card
"$ATC" state-write org/a map-1 >/dev/null <<'MD'
# Map: parcels
## #2 Research tiles
Left off: compared two tile schemes.
Next: pick one.
MD
"$ATC" sync >"$T/o" 2>&1
check "state note updates only its card" grep -q "1 updated" "$T/o"
check "card body carries left-off text" grep -q 'Left off: compared two tile schemes' "$FAKE/calls.log"

# an old map card (from an earlier version) is archived by the next sync
printf 'org/a#1\t50\tITEM1\tsig\t2026-10-15\tNext up\topen\n' >>"$ATC_DATA_DIR/index.tsv"
"$ATC" sync >"$T/o" 2>&1
check "existing map card is archived" test "$(idx 'org/a#1' 7)" = archived

# closing and hiding
jq 'map(select(.number != 2 and .number != 9))' "$FAKE/issues_open_org__a.json" >"$T/x" && mv "$T/x" "$FAKE/issues_open_org__a.json"
echo "org/a#2" >"$FAKE/closed"
"$ATC" sync >"$T/o" 2>&1
check "closed upstream moves card to Done" test "$(idx 'org/a#2' 6)" = Done
check "closed upstream closes the stub" test "$(idx 'org/a#2' 7)" = closed
check "open but hidden card is archived" test "$(idx 'org/a#9' 7)" = archived

# sync commits before and after the board work
"$ATC" state-write org/a pre-sync >/dev/null <<<"note"
"$ATC" sync >/dev/null 2>&1
subjects=$(git -C "$ATC_DATA_DIR" log --format=%s -3)
check "sync commits pending notes first" grep -q "atc update" <<<"$subjects"

# repo argument limits sync to that repo
echo org/b >>"$ATC_DATA_DIR/projects.txt"
: >"$FAKE/calls.log"
"$ATC" sync org/a >/dev/null 2>&1
check "sync with repo skips other repos" test "$(calls 'repos/org/b')" = 0
check "sync with repo reads that repo" test "$(calls 'repos/org/a')" -gt 0
check "sync refuses untracked repo" bash -c "! '$ATC' sync org/zzz"
check "sync accepts --dry-run with repo" bash -c "'$ATC' sync --dry-run org/a | grep -q dry"
grep -Fxv org/b "$ATC_DATA_DIR/projects.txt" >"$T/p" && mv "$T/p" "$ATC_DATA_DIR/projects.txt"
check "sync prints the board link" bash -c "'$ATC' sync | grep -q 'projects/7'"

# status and stale
"$ATC" status >"$T/o" 2>&1
check "status lists the repo" grep -q "== org/a" "$T/o"
check "stale finds old cards" bash -c "'$ATC' stale 0 | grep -q 'org/a#6'"

# eod helpers
cat >"$FAKE/graphql.json" <<'JSON'
{"data":{"user":{"contributionsCollection":{
 "commitContributionsByRepository":[{"repository":{"nameWithOwner":"org/a"},"contributions":{"totalCount":3}},{"repository":{"nameWithOwner":"org/new"},"contributions":{"totalCount":1}}],
 "pullRequestContributions":{"nodes":[{"pullRequest":{"number":50,"title":"Fix","url":"u","repository":{"nameWithOwner":"org/a"}}}]},
 "issueContributions":{"nodes":[]}}}}}
JSON
"$ATC" contributions >"$T/c.json" 2>&1
check "contributions flag tracked repos" jq -e 'map(select(.repo=="org/a"))|all(.tracked)' "$T/c.json"
check "contributions flag unknown repos" jq -e 'map(select(.repo=="org/new"))|all(.tracked|not)' "$T/c.json"

"$ATC" eod-write >/dev/null <<<"# EOD"
"$ATC" eod-write >/dev/null <<<"# EOD v2"
check "eod-write replaces the day's summary" test "$(cat "$ATC_DATA_DIR/logs/2026-10-16.md")" = "# EOD v2"
check "eod-write leaves jots alone" test "$(wc -l <"$J")" = 3
check "save command is gone" bash -c "! '$ATC' save x"
"$ATC" sync >/dev/null 2>&1
check "sync pushes the summary" git --git-dir="$FAKE/remote.git" show main:logs/2026-10-16.md

export ATC_DATE=2026-10-17
echo '[{"number":9,"title":"Done thing","closed_at":"2026-10-16T12:00:00Z"}]' >"$FAKE/issues_closed_org__a.json"
"$ATC" brief >"$T/o" 2>&1
check "brief shows map progress" grep -q 'Map #1 Map: parcels: 1 of 4 done' "$T/o"
check "brief shows jots since last EOD" grep -q 'remember the retry logic' "$T/o"
check "brief shows state notes" grep -q 'Left off: compared two tile schemes' "$T/o"

# --- remove ---
"$ATC" remove org/a >/dev/null 2>&1
check "remove untracks the repo" test ! -s "$ATC_DATA_DIR/projects.txt"
check "remove clears the repo's cards" test ! -s "$ATC_DATA_DIR/index.tsv"
check "remove keeps logs" test -f "$ATC_DATA_DIR/logs/2026-10-16.jots.md"
check "remove keeps state notes" test -f "$ATC_DATA_DIR/state/org__a/map-1.md"
check "remove of unknown repo fails" bash -c "! '$ATC' remove org/a"

echo "passed: $pass, failed: $fail"
"$ROOT/tests/report.sh" || fail=$((fail + 1))
[ "$fail" = 0 ]
