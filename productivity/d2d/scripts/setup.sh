# setup, add, remove, status

# Prints the plan; with --yes, creates the private data repo (or reuses an existing one),
# clones it, and records the clone path for this machine.
cmd_setup() {
  local yes=0 name="" dir="" user
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes) yes=1; shift ;;
      --name) name=$2; shift 2 ;;
      --dir) dir=$2; shift 2 ;;
      *) die "usage: d2d setup [--name <repo>] [--dir <clone path>] [--yes]" ;;
    esac
  done

  gh auth status >/dev/null 2>&1 || die "not logged in to GitHub. Run: gh auth login"
  user=$(gh api user --jq .login)
  if [ -z "$dir" ]; then
    dir="${D2D_HOME:-}"
    if [ -z "$dir" ] && [ -f "$D2D_POINTER" ]; then dir=$(cat "$D2D_POINTER"); fi
  fi
  # Already set up here: keep the repo name from d2d.json.
  [ -n "$name" ] || { [ -f "${dir:-}/d2d.json" ] && name=$(jq -r .repo "$dir/d2d.json"); } || true
  [ -n "$name" ] || name="$user-d2d"
  [ -n "$dir" ] || die "where should the data repo be cloned? Pass --dir <path>"
  dir=$(realpath -m "$dir")

  echo "Setup will use GitHub account: $user"
  echo "  1. private data repo: $user/$name (created if missing, otherwise reused)"
  echo "  2. local clone: $dir"
  if [ "$yes" = 0 ]; then
    echo "Nothing changed. Re-run with --yes to proceed."
    return 0
  fi

  if ! gh repo view "$user/$name" >/dev/null 2>&1; then
    gh repo create "$user/$name" --private --description "d2d data: daily logs and state" >/dev/null
    echo "  created repo: $user/$name"
  fi
  if [ ! -d "$dir/.git" ]; then
    mkdir -p "$(dirname "$dir")"
    gh repo clone "$user/$name" "$dir" >/dev/null 2>&1 || die "could not clone $user/$name to $dir"
  fi
  if ! git -C "$dir" config user.email >/dev/null; then
    git -C "$dir" config user.name "$user"
    git -C "$dir" config user.email "$(gh api user --jq .id)+$user@users.noreply.github.com"
  fi

  mkdir -p "$dir/logs" "$dir/state"
  [ -f "$dir/d2d.json" ] || jq -n --arg o "$user" --arg r "$name" '{owner:$o, repo:$r, tracked:[]}' >"$dir/d2d.json"
  [ -f "$dir/.gitignore" ] || printf 'reports/\n' >"$dir/.gitignore"
  [ -f "$dir/README.md" ] || printf '# %s\n\nd2d data. Managed by the d2d skills.\n\n- `d2d.json`: settings and tracked repos\n- `logs/`: daily jots and end-of-day summaries\n- `state/`: latest left-off notes\n- `reports/`: HTML reports (not committed unless you say so)\n' "$name" >"$dir/README.md"
  touch "$dir/logs/.gitkeep" "$dir/state/.gitkeep"

  printf '%s\n' "$dir" >"$D2D_POINTER"
  load_config
  data_commit "d2d setup"
  echo "Done. Data repo: https://github.com/$user/$name"
  echo "Next: run /d2d add owner/repo for each repo to track."
}

cmd_add() {
  load_config
  local repo=${1:-}
  [[ "$repo" == */* ]] || die "usage: d2d add owner/repo"
  local info
  info=$(gh repo view "$repo" --json nameWithOwner,hasIssuesEnabled 2>&1) \
    || die "cannot reach $repo (no access, or SSO needs authorizing): $info"
  [ "$(jq -r .hasIssuesEnabled <<<"$info")" = true ] || die "$repo has GitHub Issues turned off; d2d needs them"
  repo=$(jq -r .nameWithOwner <<<"$info")

  if tracked_repos | grep -Fxqi -- "$repo"; then
    echo "$repo is already tracked."
  else
    jq --arg r "$repo" '.tracked += [$r]' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    data_commit "add $repo"
    echo "Now tracking $repo."
  fi
  echo "Labels: $(gh label list -R "$repo" --limit 30 --json name --jq 'map(.name)|join(", ")')"
}

cmd_remove() {
  load_config
  local repo=${1:-}
  [[ "$repo" == */* ]] || die "usage: d2d remove owner/repo"
  tracked_repos | grep -Fxq -- "$repo" || die "$repo is not tracked"
  jq --arg r "$repo" '.tracked -= [$r]' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  data_commit "remove $repo"
  echo "Stopped tracking $repo. Logs and state notes are kept."
}

cmd_status() {
  load_config
  echo "Data repo: $OWNER/$DATA_REPO at $DATA_DIR"
  echo "Last EOD: $(last_eod_date)"
  echo "Tracked repos:"
  tracked_repos | sed 's/^/  /'
}
