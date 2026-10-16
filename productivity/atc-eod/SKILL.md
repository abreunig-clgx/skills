---
name: atc-eod
description: End-of-day routine. Retros the day's sessions per tracked project, merges jots and GitHub activity, updates state notes and the board. Use when the user says "/atc-eod", "end of day", "eod", or "wrap up the day". Run in a fresh session.
---

Close out the day so tomorrow starts fast. Run in a fresh session from any directory.

`ATC=~/.agents/skills/atc/scripts/atc`. Pass `--force` as an argument to skip the confirmation in step 8.

Hard rules: never edit or close issues in tracked repos. "Today" is the user's local calendar day. Exclude this session (`$COPILOT_AGENT_SESSION_ID`).

## Steps

1. **Tracked repos.** `$ATC projects`. If empty, tell the user to run `/atc add owner/repo` and stop.
2. **Sessions.** Use `session_store_sql` to find sessions updated today (local day) whose `repository` is a tracked repo, excluding this session. Fetch their `turns` and `checkpoints`. Group by repo.
3. **Jots.** `$ATC jots` for today's notes. Each has `repo=`, `session=`, and optional `issue=` or `map=`.
4. **Activity.** `$ATC contributions`. It returns PRs, issues and commit counts, each flagged `tracked`.
5. **Map to issues, per repo.** Match each session to an issue from issue numbers in its content, its branch, and linked PRs. A jot's `issue=` or `map=` tag overrides your guess. Read issues with `gh issue view` when you need context. Work that matches no issue goes in the repo's inbox.
6. **Write state notes.** For each repo you touched, read `~/.atc/data/state/<owner>__<repo>/` first and keep existing sections. Then write with `$ATC state-write owner/repo <name>`, one note per map (`map-<N>`), one for loose issues (`loose`), and one for unmatched work (`inbox`). Format:

   ```
   # <plain-language goal of the map, rewritten, not copied>   (maps only)
   ## #<N> <issue title>
   Left off: ...
   Next: one concrete action
   Blockers: ... or none
   Jots: the user's words
   Sessions: short IDs
   ```

   Regenerate a map's goal only if the map changed. Issue headings must be exactly `## #<N> ` because the board reads them.
7. **Write the day summary.** `$ATC eod-write` with stdin: a section per repo (what happened, PRs, sessions, jots). This replaces today's summary and never touches jots.
8. **Preview and confirm.**
   - `$ATC sync --dry-run` shows new, updated, done and hidden cards.
   - `$ATC stale 7` lists cards untouched for 7+ days.
   - List untracked repos from step 4 and ask whether to add each (`$ATC add`).
   - Show the user a short summary: per repo, left off and next. Ask to confirm with ask_user. Skip the question only with `--force`.
9. **Publish.** `$ATC save "eod <date>"` then `$ATC sync`. Report counts and the board link.

Safe to re-run the same day: state and summary are replaced, jots stay.
