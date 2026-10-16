# setup, add, remove

ensure_field() { # project-number existing-names name type [options]
  local n=$1 existing=$2 name=$3 type=$4 opts=${5:-}
  grep -Fxq "$name" <<<"$existing" && return 0
  if [ -n "$opts" ]; then
    gh project field-create "$n" --owner @me --name "$name" --data-type "$type" --single-select-options "$opts" >/dev/null
  else
    gh project field-create "$n" --owner @me --name "$name" --data-type "$type" >/dev/null
  fi
  echo "  created field: $name"
}

cmd_setup() {
  local yes=0
  [ "${1:-}" = "--yes" ] && yes=1

  gh auth status >/dev/null 2>&1 || die "not logged in to GitHub. Run: gh auth login"
  gh auth status 2>&1 | grep -q "'project'" \
    || die "token lacks the 'project' scope. Run: gh auth refresh -s project"

  local user data_repo data_dir
  user=$(gh api user --jq .login)
  data_repo="$user-atc"
  data_dir="${ATC_DATA_DIR:-$HOME/.atc/data}"

  echo "Setup will use GitHub account: $user"
  echo "  1. private data repo: $user/$data_repo (created if missing)"
  echo "  2. local clone: $data_dir"
  echo "  3. GitHub Project 'ATC' with fields, linked to the data repo"
  if [ "$yes" = 0 ]; then
    echo "Nothing changed. Re-run with --yes to proceed."
    return 0
  fi

  if ! gh repo view "$user/$data_repo" >/dev/null 2>&1; then
    gh repo create "$user/$data_repo" --private --description "ATC data: daily logs and state" >/dev/null
    echo "  created repo: $user/$data_repo"
  fi

  if [ ! -d "$data_dir/.git" ]; then
    mkdir -p "$(dirname "$data_dir")"
    gh repo clone "$user/$data_repo" "$data_dir" >/dev/null 2>&1
  fi
  if ! git -C "$data_dir" config user.email >/dev/null; then
    git -C "$data_dir" config user.name "$user"
    git -C "$data_dir" config user.email "$(gh api user --jq .id)+$user@users.noreply.github.com"
  fi

  mkdir -p "$data_dir/logs" "$data_dir/state"
  [ -f "$data_dir/projects.txt" ] || : >"$data_dir/projects.txt"
  [ -f "$data_dir/index.tsv" ] || : >"$data_dir/index.tsv"
  [ -f "$data_dir/README.md" ] || printf '# %s\n\nATC data. Managed by the atc skills.\n\n- `projects.txt`: tracked repos\n- `logs/`: daily jots and end-of-day summaries\n- `state/`: latest left-off notes\n- `index.tsv`: board bookkeeping\n' "$data_repo" >"$data_dir/README.md"
  touch "$data_dir/logs/.gitkeep" "$data_dir/state/.gitkeep"

  local n
  n=$(gh project list --owner @me --format json --jq '[.projects[]|select(.title=="ATC")|.number][0] // empty')
  if [ -z "$n" ]; then
    n=$(gh project create --owner @me --title ATC --format json --jq .number)
    echo "  created project: ATC (#$n)"
  fi

  local existing
  existing=$(gh project field-list "$n" --owner @me --format json --jq '.fields[].name')
  ensure_field "$n" "$existing" Stage SINGLE_SELECT "Inbox,Next up,In progress,Blocked,Done,Stale"
  ensure_field "$n" "$existing" "Source repo" TEXT
  ensure_field "$n" "$existing" Triage TEXT
  ensure_field "$n" "$existing" Map TEXT
  ensure_field "$n" "$existing" "Wayfinder type" TEXT
  ensure_field "$n" "$existing" "Last touched" DATE
  gh project link "$n" --owner @me --repo "$user/$data_repo" >/dev/null 2>&1 || true

  mkdir -p "$(dirname "$ATC_CONFIG")"
  printf 'OWNER=%s\nDATA_REPO=%s\nDATA_DIR=%s\nPROJECT_NUMBER=%s\n' "$user" "$data_repo" "$data_dir" "$n" >"$ATC_CONFIG"
  load_config
  data_commit "atc setup"

  echo "Done. Project: https://github.com/users/$user/projects/$n"
  cat <<'EOT'
Manual step: set up the board view in the project.
  1. Add a Board view.
  2. Column field: Stage.
  3. Group by: Source repo.
  4. Sort by: Last touched.
  5. Turn on Stage and the other fields (Triage, Map, Wayfinder type, Last touched) so they show on cards.
  6. The Stale column appears only once a card is stale. Hide it if you want.
  7. Hiding the built-in Status field is optional.
Upgrading an old board: the first sync renames titles and archives map cards.
EOT
  echo "Next: run /atc add owner/repo for each repo to track. It syncs by itself."
}

cmd_add() {
  load_config
  local repo=${1:-}
  [[ "$repo" == */* ]] || die "usage: atc add owner/repo"
  local info
  info=$(gh repo view "$repo" --json nameWithOwner,hasIssuesEnabled 2>&1) \
    || die "cannot reach $repo (no access, or SSO needs authorizing): $info"
  [ "$(jq -r .hasIssuesEnabled <<<"$info")" = true ] || die "$repo has GitHub Issues turned off; ATC needs them"
  repo=$(jq -r .nameWithOwner <<<"$info")

  if grep -Fxqi -- "$repo" "$PROJECTS"; then
    echo "$repo is already tracked."
  else
    echo "$repo" >>"$PROJECTS"
    data_commit "add $repo"
    echo "Now tracking $repo."
  fi
  cmd_sync "$repo"
  echo "Labels: $(gh label list -R "$repo" --limit 30 --json name --jq 'map(.name)|join(", ")')"
}

cmd_remove() {
  load_config
  local repo=${1:-}
  [[ "$repo" == */* ]] || die "usage: atc remove owner/repo"
  grep -Fxq "$repo" "$PROJECTS" || die "$repo is not tracked"

  local key row item
  for key in $(idx_keys_for_repo "$repo"); do
    row=$(idx_get "$key")
    item=$(cut -f3 <<<"$row")
    [ "$(cut -f7 <<<"$row")" = archived ] || gh project item-archive "$PROJECT_NUMBER" --owner @me --id "$item" >/dev/null
    idx_del "$key"
  done
  grep -Fxv "$repo" "$PROJECTS" >"$PROJECTS.tmp" || true
  mv "$PROJECTS.tmp" "$PROJECTS"
  data_commit "remove $repo"
  echo "Stopped tracking $repo. Logs and state notes are kept."
}
