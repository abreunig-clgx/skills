---
name: atc
description: Air traffic control across projects. Sets up the ATC data repo and GitHub Project board, adds or removes tracked repos, shows status. Use when the user says "/atc", "atc setup", "track this repo", "stop tracking", or asks for a cross-project status.
---

ATC gives one board across many GitHub repos, plus daily notes so work is easy to resume. It works only with GitHub Issues. Wayfinder maps and triage labels are used when present, never required.

The tool is a bash script. Run it as:

```bash
~/.agents/skills/atc/scripts/atc <command>
```

Other skills: `/atc-jot` (save a note), `/atc-eod` (end of day), `/atc-start` (morning brief).

## Setup

1. Run `atc setup` (no flag). It checks `gh` login and the `project` scope, and prints what it would create. It changes nothing.
2. If the `project` scope is missing, tell the user to run `gh auth refresh -s project` themselves (it needs a browser), then retry.
3. Show the plan. Ask the user to confirm with ask_user.
4. Run `atc setup --yes`. It creates a private `<user>-atc` repo, clones it to `~/.atc/data`, and creates the "ATC" GitHub Project with its fields. It is safe to re-run.
5. Tell the user the one manual step it prints: in the project, add a Board view, group by Stage, group rows by Repo. GitHub has no API for views.
6. Offer to add repos (below).

## Add, remove, status

- `atc add owner/repo`: starts tracking. It checks the repo is reachable, has Issues on, and prints its labels. If it reports an access or SSO error, relay it plainly.
- `atc remove owner/repo`: stops tracking and takes its cards off the board. Logs and state notes stay.
- `atc status`: cards per stage per repo, and cards untouched for 7+ days.

With no argument to `/atc`, run `atc status`; if not set up yet, start setup.

## Rules

- Never create or change anything in the user's account without confirmation.
- ATC never edits or closes issues in tracked repos. It only writes to the data repo and the board.
