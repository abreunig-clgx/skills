---
name: brief
description: Morning brief across tracked repos. Shows where you left off, every open ticket with the frontier highlighted, what closed, and open PRs with their tickets. Use when the user says "/brief", "where did I leave off", "morning brief", or "what's next".
---

Read-only. Never run `publish`, `jot` or anything that writes, except the optional HTML report in step 5.

`D2D=~/.agents/skills/d2d/scripts/d2d`

## Steps

1. Run `$D2D brief`. It prints JSON: `last_eod` (the last end-of-day summary), `jots` since then, and per tracked repo `maps` (goal, progress), `open` tickets, `closed` since the last EOD, open `prs` (with `closes`: the tickets they close), and `state` notes.
2. Where the facts aren't enough to understand a ticket, read it with `gh api repos/<repo>/issues/<n>` and `.../comments`. Comments hold decisions. Don't use `gh issue view`: it fails on repos with classic projects.
3. Write the brief in plain language. Don't paste titles or ticket text.
4. Stop after the brief. Don't ask which item to pick up.
5. Then ask (ask_user): which repos, if any, the user wants more detail on, and whether they want text or an HTML page. For each chosen repo, follow "Detail" below.

If the script says d2d isn't set up, tell the user to run `/d2d`.

## Brief format

Start with **Last time**: a compact history from `last_eod`, a few lines. If there is no EOD yet, say so.

Then, per repo, leading with the repo touched most recently:

- **Goal** (per map in `maps`): one or two sentences on why it exists, plus progress (e.g. 2 of 5 done).
- **Open tickets**: all of them, not only map tickets. Put the frontier (`frontier: true`) first and mark it. One line each on what it aims to do, with its number and triage label, e.g. `#42 (ready-for-agent)`. Show which map it belongs to if any. Flag blocked ones.
- **Closed since last time**: what was achieved, one line each.
- **Open PRs**: what each does and which ticket it closes (`closes`).
- **Left off / Next**: from `state`.
- **Your jots**: verbatim, from `jots`.

Keep it short: a few lines per repo.

## Detail

1. Find the repo's latest session in the session store. Note its date.
2. Run `$D2D detail <repo> --last-session <YYYY-MM-DD>` (leave the flag off if there is no session). It prints JSON: `since`, `maps`, `closed`, `prs` (with `summary` and `closes`), `top` (the top 3 open tickets with body, all comments and tied PRs), `left_off`, `jots`. A short repo name works if it matches one tracked repo.
3. Show sessions since `since` for this repo from the session store, a line or two each.
4. Write the report in plain language: short sentences, simple words, no pasted ticket text. Use comments: they hold decisions.
5. Use these `##` headings in order: **Goal** (with a progress bar like `[####------] 2/6`; "No map." if none), **Since you last touched it** (closed issues, PRs with the ticket each is tied to, sessions), **What is next** (top 3 in depth: what, why, how it fits the goal; never invent a fit), **Still foggy** (at most 3 lines: `needs-info` or `needs-triage` tickets), **Left off**.
6. Write ticket and PR references as `#12` and `PR #30`.
7. If the user wants HTML, pipe the report into `$D2D html <repo>` and print the path. It lands in `reports/` in the data repo and is not committed. Ask whether to commit it. If yes, run `$D2D commit-report <path>`.
