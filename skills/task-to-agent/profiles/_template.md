# Profile: <repo>

Fill every key. Use `n/a` when a step does not apply. Commands run from the worktree root.
Save as `profiles/<repo>.md` (git-ignored, stays on your machine). No absolute paths, Paradev ids or logins: SKILL.md step 0 resolves those per machine, so the profile can be copied to a teammate.
Commands must run on macOS and Linux: `perl -pi -e` instead of `sed -i ''`.

- remote: <`git remote get-url origin`>
- base_branch: <branch PRs target>
- closes_on_merge: <true if base_branch is the default branch, so `Closes #N` closes the issue>
- branch_pattern: <e.g. `feat/N-<slug>`>
- spec: <required | optional | none>
- spec_path: <e.g. `docs/specs/<name>.md`>
- spec_template: <repo copy of `../spec-template.md` at `docs/specs/_template.md`, plus repo-only sections>
- commit_types: <allowed Conventional Commit types>
- commit_scopes: <scopes in use>
- worker_trailers: <Codex / Claude / Gemini Co-Authored-By lines; ask the user for others>
- env_setup: <command that creates the worktree env file without printing it>
- isolation: <how to run a second stack beside the main one: compose project name, port variables or override>
- stack_up: <command>
- stack_down: <command>
- checks: <full test and lint commands>
- pre_push: <what the hook or CI checks that local runs can miss>
- after_rebase: <install / migrate commands>
- conflict_hotspots: <files that usually conflict>
- review_checklist: <repo-specific bugs to look for>
- pr_body: <template or example PR numbers>
- reviewer_rule: <who to request, and the exception>
- e2e: <how to run the app and drive a browser for pr-task E2E>
