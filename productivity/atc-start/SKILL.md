---
name: atc-start
description: Morning brief across tracked projects. Shows what each map is for, the aim of each open issue, what closed since last time, and where you left off. Use when the user says "/atc-start", "where did I leave off", "morning brief", or "what's next".
---

Read-only. Never run `sync`, `save`, `jot` or anything that writes.

`ATC=~/.agents/skills/atc/scripts/atc`

## Steps

1. Run `$ATC brief`. It prints, per tracked repo: issues closed since the last EOD (7 days if none), open board cards with their stage, state notes (left off, next, blockers), and jots since the last EOD.
2. For each repo, read the open map issues and open cards with `gh api repos/<repo>/issues/<n>` and `gh api repos/<repo>/issues/<n>/comments`, where the brief isn't enough to understand them. Comments hold decisions, so read them. Don't use `gh issue view`: it fails on repos with classic projects.
3. Write the brief in plain language. Don't paste titles or ticket text.

## Brief format, per repo

- **Goal** (per map): one or two sentences on why it exists, plus its progress from the brief (e.g. 2 of 5 done).
- **Closed since last time**: what was achieved, in one line each. This anchors where you stopped.
- **Open work**: one line per frontier or loose issue saying what it aims to do. Show its triage label and number, e.g. `#42 (ready-for-agent)`. Don't offer actions.
- **Left off / Next**: from the state notes.
- **Your jots**: verbatim.

Keep it short: a few lines per repo. Lead with the repo that was touched most recently.

## End

Stop after the brief. Don't ask which item to pick up.
