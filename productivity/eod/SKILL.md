---
name: eod
description: End-of-day routine. Retros the day's sessions per tracked repo, merges jots and GitHub activity, updates state notes, and publishes them. Use when the user says "/eod", "end of day", "eod", or "wrap up the day". Run in a fresh session.
---

Close out the day so tomorrow starts fast. Run in a fresh session from any directory.

`D2D=~/.agents/skills/d2d/scripts/d2d`. Pass `--force` as an argument to skip the confirmation in step 7.

Hard rules: never edit or close issues in tracked repos. "Today" is the user's local calendar day. Exclude this session (`$COPILOT_AGENT_SESSION_ID`).

## Steps

1. **Tracked repos.** `$D2D repos`. If empty, tell the user to run `/d2d add owner/repo` and stop. If the script says d2d isn't set up, tell the user to run `/d2d`.
2. **Sessions.** Use `session_store_sql` to find sessions updated today (local day) whose `repository` is a tracked repo, excluding this session. Fetch their `turns` and `checkpoints`. Group by repo.
3. **Jots.** `$D2D jots` for today's notes. Each has `repo=`, `session=`, and optional `issue=` or `map=`.
4. **Activity.** `$D2D contributions`. It returns PRs, issues and commit counts, each flagged `tracked`.
5. **Map to issues, per repo.** Match each session to an issue from issue numbers in its content, its branch, and linked PRs. A jot's `issue=` or `map=` tag overrides your guess. Read issues with `gh api repos/<repo>/issues/<n>` and `.../comments` when you need context. Comments hold decisions, so read them. Don't use `gh issue view`: it fails on repos with classic projects. Work that matches no issue goes in the repo's inbox.
6. **Write state notes and the day summary.**
   - For each repo you touched, read `<clone>/state/<owner>__<repo>/` first (the clone path is in `~/.d2d-path`) and keep existing sections. Then write with `$D2D state-write owner/repo <name>`: one note per map (`map-<N>`), one for loose issues (`loose`), and one for unmatched work (`inbox`). Format:

     ```
     # <plain-language goal of the map, rewritten, not copied>   (maps only)
     ## #<N> <issue title>
     Left off: ...
     Next: one concrete action
     Blockers: ... or none
     Jots: the user's words
     Sessions: short IDs
     ```

     Regenerate a map's goal only if the map changed.
   - `$D2D eod-write` with stdin: a section per repo (what happened, PRs, sessions, jots). This replaces today's summary and never touches jots. Keep it compact: `/brief` shows it as the history.
7. **Confirm.** List untracked repos from step 4 and ask whether to add each (`$D2D add`). Show a short summary: per repo, left off and next. Ask to confirm with ask_user. Skip the question only with `--force`.
8. **Publish.** `$D2D publish` commits and pushes the notes.
9. **Offer detail.** Ask (ask_user) which repos, if any, the user wants more detail on, and whether they want text or an HTML page. For each, follow the "Detail" section of the `/brief` skill. HTML goes to `reports/` in the data repo, is not committed, and the user is asked whether to commit it.

Safe to re-run the same day: state and summary are replaced, jots stay.
