# Agents

You are one phase of a feature, not the whole lifecycle. The human starts the next session.

## Read first

1. `context/README.md`
2. `.cursor/skills/repo-workflow/SKILL.md`
3. The feature README if the prompt names a slug

Then follow the upstream skill that `repo-workflow` names for this phase. Skills live in `.cursor/skills/`. Personas live in `.cursor/agents/` and are not loaded automatically. Read the persona file only when the prompt tells you to review, audit, or hunt for tests.

## Hard stops

- Do not invent a product, a user, or a client. The domain is unset. See `context/product/vision.md`.
- Do not write code unless the feature status is `plan-approved` or `implementing`.
- Do not plan or code in the session that just wrote the spec.
- Do not open a production deploy. Hosting is undecided.
- Do not delete ADRs or edit vendored skills.

## Done

`bin/ci` from the repository root is green, the feature status matches the artifact you wrote, and your final message says which prompt in `context/workflow/prompts.md` should run next.
