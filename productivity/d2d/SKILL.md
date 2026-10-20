---
name: d2d
description: Day to day. Sets up the private d2d data repo, adds or removes tracked repos, and explains the sub-skills /brief, /eod and /jot. Use when the user says "/d2d", "d2d setup", "track this repo", "stop tracking", or asks how the day-to-day skills fit together.
---

d2d answers one question: where did I leave off, and what is next? It works across many GitHub repos and only needs GitHub Issues. Wayfinder maps and triage labels are used when present, never required.

All sub-skills read and write one private data repo. Run the tool as:

```bash
~/.agents/skills/d2d/scripts/d2d <command>
```

## The family

- `/brief`: morning brief. Read-only. Open tickets with the frontier highlighted, what closed, open PRs, where you left off.
- `/eod`: end of day. Retros the day's sessions, writes notes, publishes them.
- `/jot`: save a note tied to the current session. It shows up in the next `/eod` and `/brief`.

Both `/brief` and `/eod` offer more detail on any repo, as text or an HTML page.

## Setup

The data repo name and clone path are the user's choice. They are not hardcoded.

1. Ask the user (ask_user) for the repo name (suggest `<user>-d2d`) and where to clone it. The clone path is per machine, so ask on every new machine.
2. Run `d2d setup --name <repo> --dir <path>` (no `--yes`). It prints the plan and changes nothing. Show it and ask the user to confirm.
3. Run it again with `--yes`. It creates the private repo, or reuses it if it already exists, then clones it. It is safe to re-run.
4. On a fresh machine where the repo already exists, run the same command. The clone brings back the settings and tracked repos. Only the local path is new.
5. Offer to add repos (below).

Settings live in `d2d.json` inside the data repo. A small pointer file, `~/.d2d-path`, records the clone path for this machine. If it is wiped, run setup again. `$D2D_HOME` overrides it.

## Add, remove, status

- `d2d add owner/repo`: starts tracking. It checks the repo is reachable and has Issues on, then prints its labels. If it reports an access or SSO error, relay it plainly.
- `d2d remove owner/repo`: stops tracking. Logs and state notes stay. This is how the user stops seeing a project's work.
- `d2d status`: data repo, last EOD, tracked repos.

With no argument to `/d2d`, run `d2d status`. If not set up yet, start setup.

## Rules

- Never create or change anything in the user's account without confirmation.
- d2d never edits or closes issues in tracked repos. It only writes to the data repo.
- HTML reports go to `reports/` in the data repo, which is gitignored. Commit one only if the user asks.
