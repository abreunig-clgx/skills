---
name: atc-report
description: One-repo report on a tracked repo - goal, what changed since you last touched it, sessions, what is next, what is still foggy, where you left off. Use when the user says "/atc-report <repo>", "report on <repo>", or "where is <repo> at". Add --show-me for an HTML page.
---

Read-only, except `--show-me`, which writes one file: `./atc-report-<repo>.html` (overwritten each run).

`ATC=~/.agents/skills/atc/scripts/atc`

`<repo>` must be tracked. A short name works if it matches one tracked repo; otherwise `atc` errors and lists the candidates. Pass that error on.

## Steps

1. Find the repo's latest session (from the session store, by repo). Note its date.
2. Run `$ATC report-data <repo> --last-session <YYYY-MM-DD>` (leave the flag off if there is no session). It prints JSON: `since` (last touched: newest of that session or a jot, else 7 days ago), `maps` (goal and progress), `closed`, `prs` (with `closes` links), `frontier` (top 3 have `detail`: body, all comments, tied PRs), `foggy`, `left_off`, `jots`.
3. Sessions: from the session store, since `since`, for this repo only. Show a compact synopsis, a line or two each.
4. Write the report in plain language. If the `wait-what` skill is installed, call it to rewrite ticket text. If not, rewrite it yourself: short sentences, simple words, no jargon, no pasted ticket text.
5. Comments are part of the ticket. They hold decisions and answers. Use them in the detail.
6. If the user passed `--show-me`, pipe the finished report into `$ATC report-html <repo>` and print the path it returns.

## Report format

Use these `##` headings, in this order:

- **Goal**: why the map exists, with its progress bar, e.g. `[####------] 2/6`. No map? Say "No map."
- **Since you last touched it**: closed issues, plus recent PRs (merged, open, closed), each with a plain description. Say which ticket each PR is tied to (`closes` and `tied PRs`). Sessions as a compact synopsis.
- **What is next**: the top 3 frontier tickets in depth. Each says what it is, why we have it, and how it fits the goal. One line each for the rest. A loose ticket (no map) says so and gives only what and why. Never invent a fit.
- **Still foggy**: at most 3 lines.
- **Left off**: from `left_off` and `jots`.

Write ticket and PR references as `#12` and `PR #30`. `report-html` turns them into links.
