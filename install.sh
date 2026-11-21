#!/usr/bin/env bash
# Link every skill in ./skills into Claude Code (~/.claude/skills) and Codex (~/.agents/skills).
# Re-run after adding a skill. `git pull` updates linked skills in place.
set -euo pipefail
repo="$(cd "$(dirname "$0")" && pwd)"
for dest in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
  mkdir -p "$dest"
  for skill in "$repo"/skills/*/; do
    target="$dest/$(basename "$skill")"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "skip $target: a real directory is there; move it away, then re-run" >&2; continue
    fi
    ln -sfn "${skill%/}" "$target"
    echo "linked $(basename "$skill") -> $dest"
  done
done
