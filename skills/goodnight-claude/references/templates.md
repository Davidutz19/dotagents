# Night log templates

Copy each block into `$NIGHT/<file>` at preflight. Times are local, ISO 8601.

## STATE.md

```markdown
# Night of <date>

Brief: <the brief, verbatim>
SKILL_DIR: <absolute path>. NIGHT: <absolute path>. Alarm: <scheduledTaskId>
Started: <time>. Wake-up: <time or none>. Last sync: <time>. Last gate: <verdict line>
Pause: <none, or the background wait's task id and the time it started>

## Preflight
- usage gate: <line>
- resource gate: <line>
- models: <catalog ids for each rung>
- .env ignored: <yes / added to .git/info/exclude / committed, parked Qn>
- forge token: <login>
- signing: <ok / parked Q1>
- toolchain: <versions>

## Map
### <repo>
- path, default branch, remote
- lint / fmt / test / audit commands
- conventions and rules from its docs
- branch rule, merge flow, PR target, protected branches
- attribution rule: <none / the trailer the repo or brief asks for>

## Backlog
| # | Item | Size | Est. min | Rung | Attempt | Depends on | Status | Branch / PR | Delegate taskId | Started |
| - | ---- | ---- | -------- | ---- | ------- | ---------- | ------ | ----------- | --------------- | ------- |

Status is one of: ready, in-flight, review, done, parked (Qn).

## EPIC threads
- <thread id>: <link>, <EPIC>, <status>

## Scheduled tasks created
- <id>: <purpose>
```

## QUESTIONS.md

```markdown
# Questions for the morning

## Q<n>. <short question>  (blocks: <item / PR>)
**Context.** What you found and where.
**Why it matters.** What goes wrong if you guess.
**Options.**
1. <option>: <trade-off>
2. <option>: <trade-off>
**Recommendation.** <option and the reason>
**Waiting on it.** <branch, partial work, next step once answered>
```

## REPORT.md

```markdown
# Night report, <date>

<two sentences: what got done, what needs the user first>

| PRs opened | Merged | Parked | Questions | Usage at start | Usage at end |
| ---------- | ------ | ------ | --------- | -------------- | ------------ |

## Needs you first
Questions that block the most work, in order, linked to QUESTIONS.md.

## Done
- #<issue> <title>: <PR link>. <one line on the approach>. Tests: <what was added>.

## In progress or parked
- #<issue>: <where it stopped, branch, what is left>

## Noticed elsewhere
Changes in other repos that affect this work, issues opened.

## Incidents
Gate pauses, resource spikes, failed delegates, and what you did.

## Worktrees left on disk
<path>: <why it was kept>

## Suggested next steps
```
