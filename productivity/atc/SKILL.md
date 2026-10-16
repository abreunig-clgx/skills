---
name: atc
description: Air traffic control across projects. Sets up the ATC data repo and GitHub Project board, adds or removes tracked repos, shows status. Use when the user says "/atc", "atc setup", "track this repo", "stop tracking", or asks for a cross-project status.
---

ATC gives one board across many GitHub repos, plus daily notes so work is easy to resume. It works only with GitHub Issues. Wayfinder maps and triage labels are used when present, never required.

The tool is a bash script. Run it as:

```bash
~/.agents/skills/atc/scripts/atc <command>
```

Other skills: `/atc-jot` (save a note), `/atc-eod` (end of day), `/atc-start` (morning brief, read-only), `/atc-sync` (update the board now), `/atc-report` (one-repo report).

## Setup

1. Run `atc setup` (no flag). It checks `gh` login and the `project` scope, and prints what it would create. It changes nothing.
2. If the `project` scope is missing, tell the user to run `gh auth refresh -s project` themselves (it needs a browser), then retry.
3. Show the plan. Ask the user to confirm with ask_user.
4. Run `atc setup --yes`. It creates a private `<user>-atc` repo, clones it to `~/.atc/data`, and creates the "ATC" GitHub Project with its fields. It is safe to re-run.
5. Tell the user the manual step it prints. GitHub has no API for views. Copy it word for word:

   ```
   Manual step: set up the board view in the project.
     1. Add a Board view.
     2. Column field: Stage.
     3. Group by: Source repo.
     4. Sort by: Last touched.
     5. Turn on Stage and the other fields (Triage, Map, Wayfinder type, Last touched) so they show on cards.
     6. The Stale column appears only once a card is stale. Hide it if you want.
     7. Hiding the built-in Status field is optional.
   Upgrading an old board: the first sync renames titles and archives map cards.
   ```

6. Offer to add repos (below).

## Add, remove, status

- `atc add owner/repo`: starts tracking. It checks the repo is reachable and has Issues on, then syncs that repo to the board by itself, then prints its labels. If it reports an access or SSO error, relay it plainly.
- `atc remove owner/repo`: stops tracking and archives its cards on the board. Logs and state notes stay.
- `atc sync [owner/repo] [--dry-run]`: update the board. Cards use the issue title. Map issues are not cards.
- `atc status`: cards per stage per repo, and cards untouched for 7+ days.

With no argument to `/atc`, run `atc status`; if not set up yet, start setup.

## Rules

- Never create or change anything in the user's account without confirmation.
- ATC never edits or closes issues in tracked repos. It only writes to the data repo and the board.
