# Can the built-in `Repository` field replace our custom repo field?

Issue: #2

## Short answer

- **No.** For ATC cards, `Repository` shows the **data repo** (`abreunig-clgx/abreunig-clgx-atc`), not the tracked repo.
- Every card has the same `Repository` value, so grouping by it gives one big group.
- We cannot set `Repository` ourselves. We still need a custom field for the tracked repo.
- The only way to make `Repository` right is to put the **real tracked issue** on the board instead of a stub. That drops the stub design.

## How stubs are modelled (repo code)

- `sync.sh` `sync_repo` creates one stub issue per tracked issue, in the data repo:
  `gh issue create -R "$DATA_FULL" ...` (sync.sh:95).
- It adds the stub to the project: `gh project item-add ... --url "$url"` (sync.sh:97).
- The tracked repo is written into a text field: `item_set "$item" Repo text "$repo"` (sync.sh:71).
- `setup.sh:66` creates that field: `ensure_field ... Repo TEXT`.
- The stub body repeats it as `**Repo:** ...` (sync.sh:47), but that is only text.

## What `Repository` shows (live check)

Checked on the real board (project #2, "ATC"), with `gh project item-list 2 --owner @me --format json`.
The first item has:

- `content.repository`: `abreunig-clgx/abreunig-clgx-atc` (the data repo)
- `repository`: `https://github.com/abreunig-clgx/abreunig-clgx-atc`
- `source repo` (our custom field): `corelogic-private/spatial_us-gis-superparcels`

The built-in field takes its value from the issue that backs the card. The stub lives in the data repo, so that is what it shows.

## Can we set `Repository`? No.

- GraphQL input type `ProjectV2FieldValue` only has: `text`, `number`, `date`, `singleSelectOptionId`, `multiSelectOptionIds`, `iterationId`.
  There is no repository input. (Introspected with `gh api graphql`.)
- The field list shows `Repository` as the built-in type `REPOSITORY`, next to Title, Assignees, Labels and so on.
- The value type `ProjectV2ItemFieldRepositoryValue` only exposes `field` and `repository`. It is read-only.
- So the repo comes from the issue, and nothing we run can change it.

## Can the board group by it?

- Yes, in the UI you can group a view by `Repository`. GitHub docs list only title, labels, reviewers and linked pull requests as ungroupable.
  Source: `github/docs`, `data/reusables/projects/customize/group-fields.md`.
- But with stubs, all cards share one repository. Grouping would show a single group, which is useless.
- So grouping by the tracked repo needs our own field (text or single select).

## Options

1. **Keep stubs and the custom text field (recommended).** Works today. Group the board by that field.
2. **Add the real issues to the board** (`gh project item-add --url <tracked issue url>`).
   `Repository` would then be right and grouping would work with no custom field.
   Costs: the stub design goes away. We lose the stub body (map, triage, state note, progress) and our control over title and body.
   We also need access to add items from every tracked repo, and each card is then a live issue, not a note we own.
   I did not test this.
3. **Single select instead of text.** Same idea as option 1, but values are fixed options. Grouping gets tidier, but `sync.sh` would have to add an option per new repo.

## Side finding: field name mismatch

- The code creates and sets a field named `Repo` (setup.sh:66, sync.sh:71).
- The live board has `Source repo` and no `Repo` (from `gh project field-list 2`).
- `item_set` looks the field up by name. With `Repo` missing, `fid` is empty and the write would fail for new or changed cards.
- Nothing in git history mentions `Source repo`. The rename was likely done by hand on the board.
- The setup message (setup.sh:79) also says "group rows by Repo".
- Fix: pick one name and use it in both scripts and the message. Not changed here, as this task is research only.

## Sources

- Repo code: `productivity/atc/scripts/setup.sh`, `sync.sh`, `lib.sh` at `main`.
- Live project data: `gh project item-list` and `gh project field-list` on project #2.
- GitHub GraphQL schema (introspection): `ProjectV2FieldValue`, `ProjectV2ItemFieldRepositoryValue`, `ProjectV2FieldConfiguration`.
- GitHub docs source: `github/docs` repo, `content/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/customizing-the-board-layout.md` and `data/reusables/projects/customize/group-fields.md`.
