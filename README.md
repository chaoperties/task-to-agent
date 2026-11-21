# task-to-agent

[![Claude Code skill](https://img.shields.io/badge/Claude_Code-skill-D97757?logo=claude&logoColor=white)](https://docs.claude.com/en/docs/claude-code/skills)
[![Requires Paradev CLI](https://img.shields.io/badge/requires-Paradev_CLI-blue)](https://docs.paradev.com/cli/getting-started)
[![Last commit](https://img.shields.io/github/last-commit/chaoperties/task-to-agent)](https://github.com/chaoperties/task-to-agent/commits/main)
[![License: MIT](https://img.shields.io/github/license/chaoperties/task-to-agent)](LICENSE)

Claude Code skill `/task-to-agent`: hand an issue, or a task on an open PR (E2E, review fixes,
follow-up), to a coding agent (Codex, Claude, Gemini, …) in its own [Paradev](https://paradev.dev)
workspace, then verify the result and open the PR yourself.

Flow: load repo profile → pick task → clarify decisions → branch + workspace + env + spec →
dispatch agent → wait in a background shell → verify (rerun checks yourself) → PR → clean up after merge.

## Install

Needs `git`, `gh` (logged in), `jq`, `perl`, Docker and the Paradev CLI (`superset`).

```bash
git clone https://github.com/chaoperties/task-to-agent.git && cd task-to-agent && ./install.sh
```

`install.sh` symlinks `skills/*` into `~/.claude/skills` and `~/.agents/skills`, so `git pull`
updates the skill. It skips a real `task-to-agent` directory that is already there.

## Use

In a repo that has a profile:

```
/task-to-agent              # pick the next ready issue
/task-to-agent 42 codex     # issue or PR #42, Codex worker
```

or say "ส่งงานให้ codex", "หา issue ถัดไป", "ให้ codex ทำ e2e PR 42".

## What's inside

| Path | Purpose |
|------|---------|
| `skills/task-to-agent/SKILL.md` | The workflow, the same for every repo |
| `skills/task-to-agent/profiles/<repo>.md` | Your profiles (git-ignored): branches, env, ports, checks, PR body, review checklist |
| `skills/task-to-agent/profiles/_template.md` | Keys a new profile must fill |
| `skills/task-to-agent/spec-template.md` | Spec template used when a profile has no repo copy |

## Profiles

The repo ships no profiles, only `_template.md`. Run `/task-to-agent` in your project: with no
matching profile the agent drafts `profiles/<repo>.md` from the project's AGENTS.md, compose file
and CI and asks you to confirm it.

Profiles are git-ignored, so they stay on your machine and `git pull` never touches them. Keep
absolute paths, Paradev project ids and logins out of them (the skill looks those up), and a
profile can be handed to a teammate as is.

## Changing the skill

`SKILL.md` wording changes how agents behave. In the PR, describe what the agent did wrong before
and the run where you checked it now behaves right.

## License

MIT, see [LICENSE](LICENSE).
