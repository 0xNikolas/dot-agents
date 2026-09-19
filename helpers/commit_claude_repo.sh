#!/usr/bin/env bash
#
# commit_claude_repo.sh
#
# Run from this repo's pre-commit lint-staged step (.lintstagedrc.mjs), after
# the root AGENTS.md changes. Copies it into ~/.claude/CLAUDE.md (the file
# ~/.claude loads as user-level context) and commits it in the ~/.claude repo.
#
# Usage: commit_claude_repo.sh [source]

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
claude_repo="$HOME/.claude"

[[ -d "$claude_repo/.git" ]] || exit 0

if (( $# > 1 )); then
  echo "usage: $0 [source]" >&2
  exit 2
fi

source_path=${1:-AGENTS.md}
if [[ "$source_path" != /* ]]; then
  source_path="$(pwd -P)/$source_path"
fi

cp -- "$source_path" "$claude_repo/CLAUDE.md"

exec "$script_dir/commit_generated_context.sh" \
  "$claude_repo" \
  "CLAUDE.md" \
  "Sync CLAUDE.md from ~/.agents commit"
