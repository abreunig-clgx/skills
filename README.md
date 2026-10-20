# skills

My personal agent skills, grouped by folder.

| Folder | What's in it |
|---|---|
| `productivity/` | d2d (day to day): morning brief, end-of-day retro, jots, across all your GitHub repos |

# d2d: setup and use

d2d answers one question: **where did I leave off, and what is next?** It works across many GitHub repos and only needs GitHub Issues. Wayfinder maps and triage labels are used when present, never required. d2d never edits or closes issues in your repos.

## The skills

| Skill | When | What it does |
|---|---|---|
| `/d2d` | Once per machine, then as needed | Setup, add or remove a repo, status, overview |
| `/jot` | Any time | Saves a note tied to this session |
| `/eod` | End of day, in a fresh session | Retro of the day, writes notes, publishes them |
| `/brief` | Morning | Plain-language brief. Read-only |

`/brief` and `/eod` both offer more detail on any repo, as text or an HTML page.

## Setup

You need `git`, `gh` (GitHub CLI) and `jq`, and a `gh` login (`gh auth status`).

1. Install the skills:

   ```bash
   gh repo clone abreunig-clgx/skills ~/skills
   mkdir -p ~/.agents/skills
   for d in d2d brief eod jot; do ln -sfn ~/skills/productivity/$d ~/.agents/skills/$d; done
   ```

   Start a new agent session so they load. Update later with `git -C ~/skills pull`.

2. In an agent session, run `/d2d`. It asks for:
   - the name of your private data repo (suggested: `<you>-d2d`),
   - where to clone it on this machine.

   It shows the plan, you confirm, and it creates the private repo (or reuses it if it exists) and clones it. Safe to re-run.

3. Track repos: `/d2d add owner/repo`. Stop with `/d2d remove owner/repo`.

On a new or wiped machine, run `/d2d` again with the same repo name. The clone brings back your settings and tracked repos.

## Daily use

- **Jot:** `/jot "retry logic lives in fetch.py"`. Add `--issue 42` or `--map 10` if it matters. Notes are append-only and pushed at once.
- **End of day:** open a fresh session, run `/eod`. It reads today's sessions, jots and GitHub activity, writes a left-off / next / blockers note per issue and a day summary, asks you to confirm (`--force` skips), then pushes to the data repo.
- **Morning:** `/brief`. It shows a compact history from the last EOD, then per repo: all open tickets with the frontier first (unblocked, and assigned to you or `ready-for-*`), what closed, open PRs with the tickets they close, where you left off, and your jots.
- **More detail:** after either, the agent asks which repos you want in depth and whether you want HTML.

## Where things live

Your data repo (the clone you chose, and `<you>/<name>` on GitHub, private):

```
d2d.json                        owner, repo name, tracked repos
logs/YYYY-MM-DD.jots.md         your jots (append only)
logs/YYYY-MM-DD.md              the day's summary (replaced on re-run)
state/<owner>__<repo>/map-N.md  a map's goal plus left-off notes
state/<owner>__<repo>/loose.md  notes for issues with no map
state/<owner>__<repo>/inbox.md  work that matched no issue
reports/                        HTML reports (gitignored; the agent asks before committing one)
```

`~/.d2d-path` holds the clone path for this machine. It is safe to lose. This skills repo is public and holds no data.

## Troubleshooting

| You see | Fix |
|---|---|
| `not set up on this machine` | Run `/d2d` |
| `cannot reach owner/repo` | You lack access, or the org needs SSO authorization |
| `has GitHub Issues turned off` | Turn Issues on for that repo |
| `push failed; committed locally` | Fine. The next jot or EOD pushes it |

## Test

```bash
bash tests/run.sh
```

Runs the real script against a fake `gh`. No network, nothing created.
