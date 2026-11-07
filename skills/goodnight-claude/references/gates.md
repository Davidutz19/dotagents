# Gate actions

The gate verdicts from `SKILL.md` that need more than one line.

## Pause and resume

A `pause` verdict means the 5-hour session is at 98 %. In-flight delegates keep running, and some may stop when the session reaches 100 %.

1. Move the alarm to the reset: call `schedule_task` with the alarm's `scheduledTaskId` and `schedule: {type: "fixed_time", timeOfDay: "<resume_at>"}`. `resume_at` comes from the usage line. If it reads `none`, use the time 5 hours from now. The alarm is the backup in case the wait below never wakes you.
2. Run `"$SKILL_DIR/scripts/usage.sh" wait` as a background Bash command with `timeout: 7200000`. The default background timeout is 30 minutes and would kill the wait. Pass its task id to `t3_background_wait`, write it on the `Pause:` line of `STATE.md`, journal the pause, and end the turn.
3. When the wait exits, act on its code:
   - 0: resume, below.
   - 20: the wait reached its 100-minute limit. Relaunch it as in step 2.
   - 30: the weekly stop fired. Go to **Closing**.
   - Any other code (killed, crashed): run `usage.sh` and act on its verdict.

Any other turn that starts while the `Pause:` line names a wait (the alarm, a delegate completion) runs `usage.sh`. On `pause`, end the turn without starting a second wait. On any other verdict, resume. When the wait exits after that, the shift is already running and the exit changes nothing.

To resume:

1. Switch the alarm back with `schedule_task`, its `scheduledTaskId` and `schedule: {type: "interval", everyMs: 1800000}`. Set the `Pause:` line to `none`.
2. Read the completions of the delegates `STATE.md` lists as in flight. A delegate that stopped on the usage limit has not failed an attempt. Relaunch it on the same rung with a brief that continues from its branch.
3. Journal the resume and continue the work loop.

The pause is done when the alarm is back on its 30-minute interval and every in-flight delegate is either running or recorded as finished.

## Unknown

`unknown` means the usage endpoint gave no reading, so the weekly cap cannot be checked. The line's `reason=` says why:

| Reason | Meaning and action |
| --- | --- |
| `missing-jq`, `missing-curl` | Run the scripts as `nix shell nixpkgs#jq nixpkgs#curl -c <script>`. Record the wrapped command in `STATE.md` and use it all night. |
| `no-token`, `http-401` | The OAuth token is missing or expired. Claude Code refreshes it while it runs, so a later turn usually clears it. |
| `http-429`, `http-5xx`, `network`, `bad-body` | A transient failure. Re-check next turn. |

At preflight, an `unknown` that the next alarm does not clear means the shift cannot enforce the weekly cap. Write it as the first question and go to **Closing**. During the night, keep the shift throttled until a reading comes back, and list any `unknown` stretch over an hour under Incidents in the report.

## Critical

`reason=` names the resource:

- `mem` or `load`: stop the heaviest job you started, either its delegate with `task_cancel` or the build process you launched. Processes you did not start stay running. A job stopped this way has not failed an attempt. Relaunch it once the gate reads `ok`.
- `disk`: delete build output (`target/`, `node_modules/`, `dist/`) inside your own worktrees whose branch is pushed. If that frees too little, start no new builds until the gate reads `ok`.
