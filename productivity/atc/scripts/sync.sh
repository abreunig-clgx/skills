# sync: mirror actionable GitHub issues onto the ATC board as stub issues.

# Normalize open issues of one repo into card rows (one JSON object per line).
cards_for_repo() { # repo me
  gh api "repos/$1/issues?state=open&per_page=100" --paginate | jq -s 'add // []' | jq -c --arg me "$2" '
    def canon: ["needs-triage","needs-info","ready-for-agent","ready-for-human","wontfix"];
    map(select(has("pull_request")|not)) as $all
    | ($all | map(select(.labels|map(.name)|index("wayfinder:map"))) | map({key:(.number|tostring), value:.title}) | from_entries) as $maps
    | $all[]
    | (.labels|map(.name)) as $l
    | ([.assignees[].login]) as $as
    | (($l|map(select(startswith("wayfinder:") and . != "wayfinder:map"))|.[0] // "")|sub("wayfinder:";"")) as $wf
    | ((.parent_issue_url // "") | split("/") | (last // "")) as $p
    | {
        number, title, url: .html_url, updated: .updated_at[:10],
        is_map: ($l|index("wayfinder:map") != null),
        wf: $wf,
        map: (if $maps[$p] then "#\($p) \($maps[$p])" else "" end),
        blocked: ((.issue_dependencies_summary.blocked_by // 0) > 0),
        mine: ($as|index($me) != null),
        assigned: ($as|length > 0),
        triage: (([canon[] | select(. as $c | $l|index($c))]|.[0]) // $l[0] // "none"),
        progress: (if .sub_issues_summary then "\(.sub_issues_summary.completed)/\(.sub_issues_summary.total)" else "" end),
        stale: (($l|index("wontfix") != null) or ((now - (.updated_at|fromdateiso8601)) > 7776000))
      }
    | select(.is_map or .wf == "" or .mine or ((.blocked or .assigned)|not))
    | . + {stage:
        (if .stale then "Stale"
         elif .blocked and .mine then "Blocked"
         elif .mine then "In progress"
         elif .is_map or .wf != "" then "Next up"
         elif (.triage|startswith("ready-")) then "Next up"
         else "Inbox" end)}'
}

# The "## #N" section for an issue from any state note of the repo.
state_section() { # repo number
  local f
  for f in "$DATA_DIR/state/$(repo_slug "$1")"/*.md; do
    [ -f "$f" ] || continue
    awk -v h="## #$2 " 'index($0,h)==1 {on=1; next} /^## / {on=0} on' "$f"
  done
}

stub_body() { # key row
  local key=$1 row=$2 repo=${1%%#*} num=${1##*#}
  printf '<!-- atc:%s -->\n**Issue:** %s\n**Repo:** %s  \n**Triage:** %s\n' "$key" "$(jq -r .url <<<"$row")" "$repo" "$(jq -r .triage <<<"$row")"
  local m p
  m=$(jq -r .map <<<"$row"); [ -z "$m" ] || printf '**Map:** %s\n' "$m"
  p=$(jq -r .progress <<<"$row"); [ -z "$p" ] || printf '**Progress:** %s\n' "$p"
  local s
  s=$(state_section "$repo" "$num")
  [ -z "$s" ] || printf '\n---\n%s\n' "$s"
}

item_set() { # item field-name kind value
  local item=$1 name=$2 kind=$3 val=$4 fid oid
  fid=$(jq -r --arg n "$name" '.fields[]|select(.name==$n)|.id' <<<"$FIELDS")
  case "$kind" in
    text) gh project item-edit --id "$item" --project-id "$PROJECT_ID" --field-id "$fid" --text "$val" >/dev/null ;;
    date) gh project item-edit --id "$item" --project-id "$PROJECT_ID" --field-id "$fid" --date "$val" >/dev/null ;;
    select)
      oid=$(jq -r --arg n "$name" --arg v "$val" '.fields[]|select(.name==$n)|.options[]|select(.name==$v)|.id' <<<"$FIELDS")
      gh project item-edit --id "$item" --project-id "$PROJECT_ID" --field-id "$fid" --single-select-option-id "$oid" >/dev/null ;;
  esac
}

set_all_fields() { # item repo row touched
  local item=$1 repo=$2 row=$3 touched=$4
  item_set "$item" Stage select "$(jq -r .stage <<<"$row")"
  item_set "$item" Repo text "$repo"
  item_set "$item" Triage text "$(jq -r .triage <<<"$row")"
  item_set "$item" Map text "$(jq -r .map <<<"$row")"
  item_set "$item" "Wayfinder type" text "$(jq -r 'if .is_map then "map" else .wf end' <<<"$row")"
  item_set "$item" "Last touched" date "$touched"
}

sync_repo() { # repo dry
  local repo=$1 dry=$2 row key n title body sig touched stage line stub item state
  local seen=" "
  while read -r row; do
    [ -n "$row" ] || continue
    n=$(jq -r .number <<<"$row"); key="$repo#$n"; seen+="$key "
    title="[$repo#$n] $(jq -r .title <<<"$row")"
    body=$(stub_body "$key" "$row")
    touched=$(jq -r .updated <<<"$row")
    stage=$(jq -r .stage <<<"$row")
    sig=$(printf '%s\n%s\n%s' "$title" "$body" "$(jq -c 'del(.url,.number,.title)' <<<"$row")" | sha1sum | cut -c1-12)
    line=$(idx_get "$key")

    if [ -z "$line" ]; then
      echo "  + $key [$stage]"; N_NEW=$((N_NEW+1))
      [ "$dry" = 1 ] && continue
      local url
      url=$(gh issue create -R "$DATA_FULL" --title "$title" --body "$body")
      stub=${url##*/}
      item=$(gh project item-add "$PROJECT_NUMBER" --owner @me --url "$url" --format json --jq .id)
      set_all_fields "$item" "$repo" "$row" "$touched"
      idx_put "$key" "$stub" "$item" "$sig" "$touched" "$stage" open
    else
      IFS=$'\t' read -r _ stub item _sig _t _s state <<<"$line"
      if [ "$state" = open ] && [ "$_sig" = "$sig" ]; then continue; fi
      echo "  ~ $key [$stage]"; N_UPD=$((N_UPD+1))
      [ "$dry" = 1 ] && continue
      [ "$state" = open ] || gh project item-archive "$PROJECT_NUMBER" --owner @me --id "$item" --undo >/dev/null
      gh issue edit "$stub" -R "$DATA_FULL" --title "$title" --body "$body" >/dev/null
      [ "$state" = closed ] && gh issue reopen "$stub" -R "$DATA_FULL" >/dev/null
      set_all_fields "$item" "$repo" "$row" "$touched"
      idx_put "$key" "$stub" "$item" "$sig" "$touched" "$stage" open
    fi
  done < <(cards_for_repo "$repo" "$ME")

  # Indexed cards that are no longer shown: closed upstream -> Done, otherwise hide.
  for key in $(idx_keys_for_repo "$repo"); do
    [[ "$seen" == *" $key "* ]] && continue
    IFS=$'\t' read -r _ stub item sig touched stage state <<<"$(idx_get "$key")"
    [ "$state" = open ] || continue
    if [ "$(gh api "repos/$repo/issues/${key##*#}" --jq .state)" = closed ]; then
      echo "  ✓ $key done"; N_DONE=$((N_DONE+1))
      [ "$dry" = 1 ] && continue
      item_set "$item" Stage select Done
      gh issue close "$stub" -R "$DATA_FULL" >/dev/null
      idx_put "$key" "$stub" "$item" "$sig" "$touched" Done closed
    else
      echo "  - $key hidden"; N_HIDE=$((N_HIDE+1))
      [ "$dry" = 1 ] && continue
      gh project item-archive "$PROJECT_NUMBER" --owner @me --id "$item" >/dev/null
      idx_put "$key" "$stub" "$item" "$sig" "$touched" "$stage" archived
    fi
  done
}

cmd_sync() { # [owner/repo] [--dry-run]
  load_config
  local dry=0 only="" arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry=1 ;;
      */*) only=$arg ;;
      *) die "usage: atc sync [owner/repo] [--dry-run]" ;;
    esac
  done
  [ -z "$only" ] || grep -Fxq "$only" "$PROJECTS" || die "$only is not tracked"
  DATA_FULL="$OWNER/$DATA_REPO"
  ME=$(gh api user --jq .login)
  PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner @me --format json --jq .id)
  FIELDS=$(gh project field-list "$PROJECT_NUMBER" --owner @me --format json)
  N_NEW=0 N_UPD=0 N_DONE=0 N_HIDE=0

  # Commit pending notes first so they go out even if the board work fails.
  [ "$dry" = 1 ] || data_commit "atc update $(today)"
  local repo
  for repo in ${only:-$(tracked_repos)}; do
    echo "$repo"
    sync_repo "$repo" "$dry"
  done
  echo "Board: $N_NEW new, $N_UPD updated, $N_DONE done, $N_HIDE hidden$([ "$dry" = 1 ] && echo ' (dry run, nothing written)')"
  echo "Board link: https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
  # Second commit picks up index.tsv.
  [ "$dry" = 1 ] || data_commit "sync board $(today)"
}
