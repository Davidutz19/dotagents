# Delegation

How the night shift hands work to other agents: which tool, which model, which effort, and what the brief contains.

## Which tool

| Need | Tool |
| --- | --- |
| A ticket that produces a branch and a PR | `delegate_task` with `isolation: "worktree"`, `mode: "async"`, `role: "implementation"`. Keep the `taskId` in `STATE.md`. Follow the `next` it returns instead of polling. |
| Read-only sweep: mapping repos, finding call sites, reading docs | Native `Agent` with `subagent_type: "Explore"` and `run_in_background: false`. Results come back in the same turn. |
| An independent review of a finished branch | `delegate_task` with `role: "review"` and `isolation: "shared"` pointed at the branch, or a fresh `Agent`. Give it the diff and the issue, never your own verdict. |
| An EPIC with more than three tickets that needs its own orchestration | `t3_thread_launch` with `workspaceStrategy: {type: "worktree", baseRef: "<default branch>"}` and a full brief. This skill's invocation is the user's request for new threads. The brief names `<SKILL_DIR>/SKILL.md` as the rules for gates, git and the definition of done. Record its `link` and thread id in `STATE.md` and the report, and read it with `t3_thread_read` before closing. On `wind-down`, tell it with `t3_thread_send` to finish in-flight work and launch nothing new. On `stop`, stop it with `t3_thread_interrupt` and `stop: true`. |

Use the model ids from the `orchestrator_capabilities` catalog you read at preflight, never guessed ones.

## Which model and effort

Each item starts at the cheapest rung that is still expert at the task:

| Rung | Model | Effort | Starting rung for |
| --- | --- | --- | --- |
| 1 | `claude-haiku-5-5` | `medium` | Search, mapping, listing, log reading, mechanical edits (renames, formatting, dependency bumps without API change) |
| 2 | `claude-sonnet-5-5` | `high` | Standard ticket (S or M): a feature within an existing design, a bug with a known cause, tests, docs |
| 3 | `claude-opus-5-5` | `high` | L ticket, cross-module design, migrations, concurrency, security-sensitive code, an unknown-cause bug |
| 4 | `claude-opus-5-5` | `xhigh` | Nothing. Reached only after a failed attempt |
| 5 | `claude-fable-5-1` | | Nothing. The last resort, journaled with the reason |

Each failed attempt moves the item up one rung. Park it after its third failed attempt, or after a failure on rung 5. A job you stopped for a gate has not failed an attempt. Fable costs the most weekly budget, so only an L ticket that failed twice reaches it.

Reviews of M and L branches run on `claude-opus-5-5` at `medium`, outside the ladder.

## The brief

A delegate knows only what its brief says. Every implementation brief has these sections:

```
Goal: <issue title, one sentence>
Issue: <URL>, acceptance criteria copied verbatim
Repo and base: <repo path>, branch <name from the repo's branch rule in STATE.md> from <base>
Conventions: <lint, format, test, audit commands and commit style from STATE.md, with their `nix develop -c` prefix if the repo has a flake.nix; a missing tool goes into the flake's dev shell, never installed ad hoc>
Context to read first: <exact files and docs>
Already ruled out: <what you checked or tried>
Limits: the non-interactive git variables from STATE.md exported, nice -n 10, CARGO_BUILD_JOBS=<n>, one test suite at a time, no network calls outside the forge and package registries
Definition of done: <paste the section from SKILL.md>
Report back: branch, head SHA, commands run with their result, criteria met or not, open questions
Rules: commit each working step, so a stopped run leaves its work in commits. Commit as the configured identity. Attribution: <the attribution rule from STATE.md, copied verbatim>. Push only this branch. The orchestrator opens the PR unless this brief says otherwise.
```

When a delegate returns open questions, answer them from the code or docs if you can. Otherwise park the item.
