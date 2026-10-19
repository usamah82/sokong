# Upstream skills

The workflows under `.cursor/skills/` (except `repo-workflow`), plus `.cursor/references/` and `.cursor/agents/`, are vendored from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) at the commit in `.cursor/agent-skills.sha`.

License: MIT. Do not edit those files in place. Repo-specific rules belong in `.cursor/skills/repo-workflow/` and `.cursor/rules/`.

Refresh with:

```bash
git clone --depth 1 https://github.com/addyosmani/agent-skills.git /tmp/agent-skills
scripts/sync-agent-skills.sh /tmp/agent-skills
```

Cursor loads `.cursor/skills/`. It does not load `.cursor/agents/` on its own. A review session reads the persona file the prompt names.
