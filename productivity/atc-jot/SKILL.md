---
name: atc-jot
description: Save a quick note tied to the current session so it shows up in the end-of-day retro. Use when the user says "/atc-jot", "jot this", "note for later", or gives a note to remember for a project.
---

Save the user's note with one command. Works from any directory.

```bash
~/.agents/skills/atc/scripts/atc jot "the note"
```

The script tags the note with the current session ID and, if the cwd is a git repo, the repo. Optional tags:

- `--issue N`: the note belongs to issue N.
- `--map N`: the note belongs to map N.
- `--repo owner/repo`: override the repo (use when the cwd isn't that project).

## Steps

1. Use the user's words. If they say "jot this" without text, write one short sentence from the conversation capturing what they mean: the why, a decision, or what to do next.
2. If the conversation is clearly about one issue or map, add `--issue` or `--map`. Don't guess.
3. Run the command. Confirm in one line with what was saved.

If the script says ATC isn't set up, tell the user to run `/atc`. A failed push is fine: the note is saved locally and goes out next time.
