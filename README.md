# skills

My personal agent skills, grouped by folder.

| Folder | What's in it |
|---|---|
| `productivity/` | ATC (air traffic control): cross-project board, jots, end-of-day retro, morning brief |

## Install ATC

Needs `git` and `gh` (logged in).

```bash
gh repo clone abreunig-clgx/skills ~/skills
mkdir -p ~/.agents/skills
for d in ~/skills/productivity/atc*; do ln -sfn "$d" ~/.agents/skills/"$(basename "$d")"; done
```

Then run `/atc` in an agent session to set up.

Update later with `git -C ~/skills pull`. The symlinks pick up changes.
