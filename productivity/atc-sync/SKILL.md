---
name: atc-sync
description: Update the ATC board now. Use when the user says "/atc-sync", "sync the board", or "refresh atc".
---

Run the sync. Don't ask for confirmation.

```bash
~/.agents/skills/atc/scripts/atc sync
```

Add `--dry-run` only if the user asks to preview. To sync one repo, add `owner/repo`.

Report the counts (new, updated, done, hidden) and the board link from the output. If the script says ATC isn't set up, tell the user to run `/atc`.
