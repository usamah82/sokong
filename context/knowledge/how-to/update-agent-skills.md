# Update agent skills

Vendored files are pinned at the commit in `.cursor/agent-skills.sha`. `repo-workflow` is ours and must survive the sync.

```bash
git clone --depth 1 https://github.com/addyosmani/agent-skills.git /tmp/agent-skills
scripts/sync-agent-skills.sh /tmp/agent-skills
```

Read the upstream diff before you commit. Do not edit files under `.cursor/skills/` other than `repo-workflow`. If a workflow needs a repo-specific exception, put it in `repo-workflow` or in `.cursor/rules/`.

Commit the SHA change with the skill diff so the next agent can see what moved.
