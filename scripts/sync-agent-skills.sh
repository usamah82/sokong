#!/usr/bin/env bash
# Replace vendored agent-skills with a local clone, keeping repo-workflow.
set -euo pipefail

src="${1:?path to a clone of https://github.com/addyosmani/agent-skills}"
root="$(cd "$(dirname "$0")/.." && pwd)"

for dir in skills references agents; do
  if [[ ! -d "$src/$dir" ]]; then
    echo "missing $src/$dir" >&2
    exit 1
  fi
done

saved="$(mktemp -d)"
trap 'rm -rf "$saved"' EXIT
cp -a "$root/.cursor/skills/repo-workflow" "$saved/repo-workflow"

rm -rf "$root/.cursor/skills" "$root/.cursor/references" "$root/.cursor/agents"
cp -a "$src/skills" "$root/.cursor/skills"
cp -a "$src/references" "$root/.cursor/references"
cp -a "$src/agents" "$root/.cursor/agents"
cp -a "$saved/repo-workflow" "$root/.cursor/skills/repo-workflow"

git -C "$src" rev-parse HEAD > "$root/.cursor/agent-skills.sha"
echo "pinned $(cat "$root/.cursor/agent-skills.sha")"
