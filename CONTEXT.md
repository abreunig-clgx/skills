# d2d

Day-to-day tracking of where work was left off across GitHub repos.

## Language

**Data repo**:
The user's private GitHub repo that holds everything d2d writes. The user names it.
_Avoid_: board, project

**Tracked repo**:
A GitHub repo the user asked d2d to watch. Removing it is how the user stops seeing its work.
_Avoid_: project

**Jot**:
A short note the user saves at any time, tied to the session and repo it was written in.

**State note**:
The latest "left off / next / blockers" record for an issue, kept per repo.

**Day summary**:
The per-repo account of one day, written by `/eod` and shown by `/brief` as history.

**Frontier**:
Open tickets that can be worked now: not blocked, and either assigned to the user or labeled `ready-for-*`.

**Map**:
An optional wayfinder issue that groups tickets under a goal. Open tickets outside any map still count.

**Report**:
A longer write-up of one repo, as text or HTML. Offered after `/brief` and `/eod`. Saved HTML is not committed unless the user says so.
