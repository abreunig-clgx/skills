# skills

My personal agent skills, grouped by folder.

| Folder | What's in it |
|---|---|
| `productivity/` | ATC (air traffic control): one board across all your projects, jots, end-of-day retro, morning brief |

# ATC: setup and use

ATC answers one question: **where did I leave off, and what do I do next?** It works across many GitHub repos.

It does five things:

- Keeps a private data repo with your daily notes and a "left off / next" note per issue.
- Shows open, actionable issues from all your repos on one GitHub Project board.
- Lets you jot a note at any time, tied to the session you're in.
- Gives you an end-of-day routine and a morning brief.
- Updates the board on demand and writes a one-repo report.

It works only with GitHub Issues. Matt Pocock's wayfinder and triage skills are recommended but not required. ATC never edits or closes issues in your project repos.

## The skills

| Skill | When | What it does |
|---|---|---|
| `/atc` | Once, then as needed | Setup, add or remove a repo, status |
| `/atc-jot` | Any time | Saves a note tied to this session |
| `/atc-eod` | End of day, in a fresh session | Retro of the day, updates notes and the board |
| `/atc-start` | Morning | Plain-language brief. Read-only. It stops after the brief |
| `/atc-sync` | Any time | Updates the board now. No questions asked |
| `/atc-report <repo>` | Any time | Report on one repo. Add `--show-me` for an HTML page |

## Part 1: One-time setup

You need `git`, `gh` (GitHub CLI 2.40 or newer), and `jq`. You need to be logged in to `gh` as the account that will own the board.

### Step 1. Check your login

```bash
gh auth status
```

You should see "Logged in to github.com account <you>". If not, run `gh auth login` and follow the prompts.

### Step 2. Add the `project` permission

GitHub Projects needs a token scope that `gh` doesn't request by default.

```bash
gh auth refresh -s project
```

1. The command prints a one-time code and a URL (`https://github.com/login/device`).
2. Open the URL in a browser. If you're on a remote machine, copy the URL to your laptop's browser.
3. Enter the code and click **Authorize**.
4. If your organization uses SSO, click **Authorize** next to the org when GitHub asks.
5. Check it worked: `gh auth status` should now list `'project'` under "Token scopes".

### Step 3. Install the skills

```bash
gh repo clone abreunig-clgx/skills ~/skills
mkdir -p ~/.agents/skills
for d in ~/skills/productivity/atc*; do ln -sfn "$d" ~/.agents/skills/"$(basename "$d")"; done
```

This links six skills: `atc`, `atc-jot`, `atc-eod`, `atc-start`, `atc-sync`, `atc-report`. Start a new agent session so they load.

Update later with `git -C ~/skills pull`. The links pick up changes.

### Step 4. Run setup

In an agent session, run `/atc`. The agent first runs a dry run and shows you the plan:

- A **private** repo `<your-username>-atc` (your data).
- A local copy at `~/.atc/data`.
- A GitHub Project named **ATC**, linked to that repo, with these fields: Stage, Source repo, Triage, Map, Wayfinder type, Last touched.

Confirm, and the agent runs the real setup. It's safe to run again: it never duplicates anything.

Or run it yourself:

```bash
~/.agents/skills/atc/scripts/atc setup          # shows the plan, changes nothing
~/.agents/skills/atc/scripts/atc setup --yes    # does it
```

### Step 5. Create the board view (by hand, once)

GitHub has no API for views, so this one step is manual. Setup prints the project link.

1. Open the project: `https://github.com/users/<your-username>/projects/<number>`. Or go to your profile, then **Projects**, then **ATC**.
2. Click **+ New view** and pick **Board**. Name it `ATC board`.
3. Follow the checklist that `atc setup --yes` prints. Here it is, word for word:

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

### Step 6. Add your projects

```
/atc add owner/repo
```

Do this for each repo you want on the board. It checks that the repo is reachable and that Issues are on. It then syncs that repo to the board by itself and shows its labels. If you get an access or SSO error, authorize your token for that organization (GitHub, **Settings**, **Applications**, or the SSO prompt) and retry.

To stop tracking: `/atc remove owner/repo`. Its cards are archived on the board. Your logs and notes stay.

## Part 2: Daily use

### During the day: jot

```
/atc-jot "retry logic lives in fetch.py; don't touch the cache layer"
```

- It saves the note with the current session ID and repo. It works from any directory.
- Say which issue it belongs to if it matters: `--issue 42` or `--map 10`.
- Notes are only added, never rewritten. It commits and pushes at once. If the push fails, the note stays local and goes out next time.

### End of day: `/atc-eod`

1. Open a **fresh** agent session. Any directory works.
2. Run `/atc-eod`.
3. The agent:
   - finds today's sessions for each tracked repo (not itself),
   - adds your jots and your day's PRs, issues and commits,
   - matches the work to issues (your tags win over its guesses),
   - writes a "left off / next / blockers" note per issue and a summary for the day.
4. It then shows a preview: cards to add, update, complete or hide, cards untouched for 7+ days, and any repos you touched that aren't tracked yet. You confirm before anything is published.
5. Add `--force` to skip the confirmation once you trust it.

Re-running on the same day is safe. The summary and notes are replaced. Your jots stay.

### Morning: `/atc-start`

It is a brief only. It reads, writes nothing, and stops after the brief. It does not ask what to pick up. Per project:

- What each map is for, with its progress.
- What closed since your last end-of-day.
- What each open issue aims to do, with its number and triage label.
- Where you left off, the next step, and your jots.

### Any time: sync

```
/atc-sync
```

Updates the board now. It asks nothing. To preview, run `~/.agents/skills/atc/scripts/atc sync --dry-run`. `/atc add` and `/atc-eod` also sync.

### Any time: report

```
/atc-report owner/repo
```

A report on one tracked repo: goal, what changed since you last touched it, what is next, what is still foggy, where you left off. A short name works if it matches one tracked repo. Add `--show-me` to write `./atc-report-<repo>.html`.

### Any time: status

```
/atc
```

Shows cards per stage per project, and cards untouched for 7+ days.

## What shows up on the board

Each card is a small stub issue in your private data repo. Its title is the issue title. The **Source repo** field says which repo it came from. The card links to the real issue and carries its notes.

| Issue | On the board? | Stage |
|---|---|---|
| Wayfinder map (`wayfinder:map`) | No. It shows as the **Map** field and progress on its tickets | n/a |
| Wayfinder ticket, open and not blocked | Yes | Next up |
| Wayfinder ticket assigned to you | Yes | In progress (Blocked if it has open blockers) |
| Wayfinder ticket that is blocked, or assigned to someone else | No | n/a |
| Any other open issue | Yes | Next up if `ready-for-*`, else Inbox |
| `wontfix`, or no activity for 90+ days | Yes | Stale |
| Closed on GitHub | Moved to Done, stub closed | Done |

The **Triage** field shows one of `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix` if the issue has it. Otherwise it shows the issue's first label, or `none`. Maps are optional: issues without one just sit under their repo.

## Where things live

Your data repo (`~/.atc/data`, and `<you>-atc` on GitHub):

```
projects.txt                    tracked repos
logs/YYYY-MM-DD.jots.md         your jots (append only)
logs/YYYY-MM-DD.md              the day's summary (replaced on re-run)
state/<owner>__<repo>/map-N.md  a map's goal plus left-off notes
state/<owner>__<repo>/loose.md  notes for issues with no map
state/<owner>__<repo>/inbox.md  work that matched no issue
index.tsv                       board bookkeeping
```

This skills repo is public and holds no data. Nobody else sees your data repo.

## Troubleshooting

| You see | Fix |
|---|---|
| `token lacks the 'project' scope` | Step 2 |
| `not set up. Run: atc setup --yes` | Step 4 |
| `cannot reach owner/repo` | You lack access, or the org needs SSO authorization (Step 2, item 4) |
| `has GitHub Issues turned off` | Turn Issues on for that repo; ATC needs them |
| Board is empty after `/atc add` | Run `/atc-sync` |
| `push failed; committed locally` | Fine. The next jot, sync or EOD pushes it. Check your connection |
| Board shows columns wrong | Re-check Step 5: Column field must be **Stage**, Group by **Source repo** |

## Test

```bash
bash tests/run.sh
```

```bash
bash tests/report.sh
```

Run the scripts against a fake `gh`. No network, nothing created.
