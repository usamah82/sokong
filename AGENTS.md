# Agents

You are one phase of a feature until the plan is approved. The human starts the next session through that point.

After `plan-approved`, you are the implementer for every remaining task. ADR-0007 is the rule. Spawn only `code-reviewer`, `security-auditor`, `test-engineer`, and `web-performance-auditor`. They comment on the task pull request and stop. You merge that pull request into the feature branch. The human is next when the spec or the task would have to change, or when the feature branch is ready for `main`.

## Read first

1. `context/README.md`
2. `.cursor/skills/repo-workflow/SKILL.md`
3. The feature README if the prompt names a slug

Then follow the upstream skill that `repo-workflow` names for this phase. Skills live in `.cursor/skills/`. Personas live in `.cursor/agents/`. The implementer spawns one by name. Any other session reads a persona file only when its prompt says to.

## Hard stops

- The product is Sokong, assessed with Mara. Read `context/product/vision.md` and `context/product/concepts.md`.
- Do not add a feature that is not in `context/product/master-feature-list.md`.
- Do not start a feature PRD unless a human names the feature and the questions that block it are answered in `context/product/open-questions.md`.
- Do not answer those questions yourself.
- Do not write code unless the feature status is `plan-approved` or `implementing`.
- Do not plan or code in the session that just wrote the spec.
- Do not open a production deploy. Hosting is undecided.
- Do not delete ADRs or edit vendored skills.

## Done

`bin/ci` from the repository root is green, the feature status matches the artifact you wrote, and your final message says which prompt in `context/workflow/prompts.md` should run next.
