---
name: task-to-agent
argument-hint: "[issue#|pr#] [codex|claude|gemini|opencode|cursor-agent|…]"
description: Use when the user wants an issue or a task on an existing PR (E2E run, review fixes, follow-up) handed to a coding agent in a Paradev workspace, in any repo that has a profile here. Triggers include "ส่งงานให้ codex", "ส่งงานให้ claude", "หา issue ถัดไป", "/task-to-agent <N> [agent]", "ให้ codex ทำ e2e PR N", or repeating this workflow.
---

# Task → agent

You coordinate and verify. A worker agent in its own Paradev workspace does the work.
This file is the same for every repo. Everything repo-specific comes from a **profile** in `profiles/`.
Reply in the user's language.

## Step 0. Load the profile

1. `git remote get-url origin` in the current repo (or the repo the user names).
2. Open the file in `profiles/` whose `remote:` matches. Read it fully. Later steps say "profile: <key>" for its values.
3. No match → stop. Copy `profiles/_template.md` to `profiles/<repo>.md`, fill it from the repo's AGENTS.md, DEVELOPMENT.md, docker compose file and CI, then ask the user to confirm it before continuing. Profiles are git-ignored: they stay on this machine.
4. Resolve the per-machine values. Profiles never store them:
   - `main_checkout`: `git rev-parse --show-toplevel` of the main checkout (not a worktree).
   - `paradev_project_id`: `superset projects list --local --json | jq -r --arg r "<remote without .git>" '.[] | select(.repo == $r) | .id'`. None → ask the user to add the repo in Paradev. Several → ask which one.
   - `github_account`: `gh api user --jq .login`.

Done when: you have every profile key and per-machine value, or the user has confirmed a new profile.

## Step 1. Pick the mode and the task

Args: `[N] [agent]`. `agent` is a Paradev preset id (`superset agents list --local --json | jq -r '.[].presetId'`).

| Mode | When | Branch | Output |
| --- | --- | --- | --- |
| **issue** | N is an issue, or no N | new branch from profile: base_branch | new PR |
| **pr-task** | N is an open PR (E2E, review fixes, follow-up) | the PR's head branch | commits on the PR, or a PR comment only |

- No N: list open issues and pick one whose dependencies are merged into profile: base_branch and whose files do not overlap running workers. Name any overlap.
- Depends on an open PR: do steps 2-3, then dispatch only after that PR merges. Check with `gh pr view <dep> --json state` and `git log origin/<base_branch>`.
- pr-task on someone else's PR: test-only or comment-only unless the user says to push to it.

Done when: mode, N, agent and branch are fixed.

## Step 2. Clarify

Read the issue or PR, its comments and the current code. Ask the user with `AskUserQuestion` (recommended option first) about anything touching public API shape, security or credentials, data ownership, billing, or anything hard to reverse. If no agent was given, ask in the same call: Codex (Recommended), Claude, Gemini.

Decide small details yourself and list them in the spec and in your reply so the user can veto them.

Done when: no open material decision remains.

## Step 3. Branch, workspace, env, spec

1. Confirm with the user that PRs open as `github_account` (step 0) if the profile's reviewer_rule names someone else.
2. Branch:
   - issue: `gh issue develop N --base <base_branch> --name <branch_pattern>` then `git fetch -q origin <branch>`
   - pr-task: `git fetch -q origin <head>:<head>`
3. Workspace: `superset workspaces create --local --project <paradev_project_id> --name "#N <title>" --branch <branch> --skip-branch-prefix --json`, then re-read id and path with `superset workspaces list --local --json` (create may print nulls; never retype ids).
   If the worktree reused an existing local branch, confirm its commits are in origin, then `git reset --hard origin/<branch>`.
4. Env: run profile: env_setup in the worktree. Never print, copy or read the main checkout's env file.
5. Spec (profile: spec):
   - `required`, or `optional` and the task changes behavior: write it at profile: spec_path from profile: spec_template, cite code as `path:line`, code wins over docs. Commit `docs: add <topic> spec (#N)` (scope per profile: commit_scopes) with the coordinator trailer and push.
   - pr-task: no spec file. The prompt in step 4 is the spec.

Done when: workspace path exists, env is in place, and the spec (if any) is pushed.

## Step 4. Dispatch

Pick isolated resources per profile: isolation (ports, compose project name). Check `docker ps` for taken ports. Write the prompt to the scratchpad, then:

```bash
superset agents create --workspace <ws> --local --agent <agent> --prompt "$(cat <prompt file>)" --json   # keep sessionId
```

The prompt contains, in this order:
1. task id, branch, target (profile: base_branch for a PR, or "no PR"), "read the spec (or this prompt), AGENTS.md and referenced docs fully"
2. rebase line if the base moved after the branch was cut (`git rebase origin/<base>`, later `--force-with-lease`)
3. the numbered work list
4. other running workers and the files to avoid
5. "No scope beyond the work list / ไม่รวม"
6. "Spec vs code conflict: code wins, note it in handoff, keep going"
7. env rule from profile: env_setup ("exists; don't read, copy or modify it")
8. stack up command and checks from profile: stack_up, profile: checks, profile: pre_push
9. commit rules: profile: commit_types, worker trailer from profile: worker_trailers, push; no PR. pr-task test-only: "do not commit or push tracked files"
10. "Do the whole task in this run. Do not end your turn after setup, with partial results, or with a failing test. BLOCKED only for a decision only the coordinator can make."
11. the envelope:

```text
SUPERSET_WORKER_DONE
task: <id>
summary: …
files: …
checks: …
handoff: …
```

or `SUPERSET_WORKER_BLOCKED` with `task`, `reason`, `needs`.

Done when: the agent session id is recorded.

## Step 5. Wait (background shell, never a subagent or polling)

One `Bash` call with `run_in_background: true`:

```bash
W=<ws>; T=<sid>
until superset agents wait --workspace $W --local --terminal $T --until settled --timeout 540 --json >/dev/null 2>&1; do sleep 1; done
superset terminals read --workspace $W --local --terminal $T --max-lines 240 --json | jq -r .text | grep -v '^\s*$' | tail -60
```

On the notification, classify:
- **DONE**: a filled-in `SUPERSET_WORKER_DONE` (not the prompt's template).
- **ERROR**: BLOCKED, crash, rate limit, permission prompt, or idle without an envelope.
- **Still working** (settled on a transient prompt): relaunch the same wait.
- After a follow-up, only read text after the follow-up's first words.

## Step 6. On ERROR

Read the screen. Resolve real questions yourself (code wins, existing contract) or ask the user if material. Then:
`superset terminals send --workspace <ws> --local --terminal <sid> --text "Decision: … Continue now. Work through items 1-N without ending your turn."` and relaunch step 5.
Two stalls in a row → split into smaller follow-ups.

## Step 7. On DONE: verify

In the worker's worktree and stack. Report numbers you ran yourself, not the worker's claims.

1. Rebase if profile: base_branch moved. Resolve conflicts (profile: conflict_hotspots: keep both sides), rerun profile: after_rebase, push `--force-with-lease`.
2. `git diff --stat origin/<base>...origin/<branch>`: scope matches the work list, read the core change and any infra file.
3. Apply profile: review_checklist.
4. Run profile: checks and profile: pre_push yourself.
5. Fix small CI issues yourself (`chore: …` with the coordinator trailer).
6. Output:
   - issue: `gh pr create --base <base> --head <branch>` with profile: pr_body (closing line, summary, checks you ran, deploy notes, footer). Request review per profile: reviewer_rule. Run `gh pr checks <PR> --watch` in the background.
   - pr-task: post results as a PR comment following the repo's review conventions (AGENTS.md, CONTRIBUTING.md), or push and comment what changed.
   - Do not merge unless the user asks.

## Step 8. Report

Short: status per task, branch and workspace, PR or comment link, decisions you made without asking, what waits on the user. Give files as full absolute paths.

## Step 9. After merge: close and clean up

Skip cleanup if the user wants the stack or workspace kept.

1. `gh pr view <PR> --json state` = `MERGED` and the squash commit is in `git log origin/<base>`.
2. Close the issue only if profile: closes_on_merge is `false`: `gh issue close N --comment "Implemented in #PR (<sha>)."`
3. In the worktree: `git status --porcelain` is empty and `git rev-parse HEAD` = PR `headRefOid`. Otherwise stop and ask: archiving deletes uncommitted files.
4. profile: stack_down.
5. `superset terminals close --workspace <ws> --local --terminal <sid> --json`
6. `superset workspaces archive <ws> --local --json`
7. Main checkout: `git worktree prune && git branch -D <branch>`; `git push origin --delete <branch>` only if `git ls-remote --heads origin <branch>` still lists it.
8. Report in one line what you removed.

## Notes for every repo

- A code index (e.g. trace-mcp), if you have one, covers only the main checkout. Read worktree files with `Read`, list changes with `git diff --name-only`.
- A pr-task on another author's PR is test or comment only by default.
- `superset:orchestrate` has the CLI details if a command fails.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| Using one repo's commands in another | Every command with a repo value comes from the profile |
| Retyping a workspace or terminal id | Copy from `workspaces list` or the create output |
| Trusting "merged" or "tests pass" from the worker | Check `gh pr view` and rerun checks yourself |
| Polling the worker or waiting with a subagent | One background `until … wait` shell |
| Writing a spec for a pr-task | The prompt is the spec |
