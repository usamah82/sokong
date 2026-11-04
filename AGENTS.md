# Agents

You are one hop of a feature, not the whole lifecycle. After plan approval, do the one build-loop action in the feature `handoff.md` and stop. The human, or later a runner outside the chat, starts the next session.

## Read first

1. `context/README.md`
2. `.cursor/skills/repo-workflow/SKILL.md`
3. The feature README if the prompt names a slug

Then follow the upstream skill that `repo-workflow` names for this phase. Skills live in `.cursor/skills/`. Personas live in `.cursor/agents/` and are not loaded automatically. Read the persona file only when the prompt tells you to review, audit, or hunt for tests.

## Hard stops

- The product is Sokong, assessed with Mara. Read `context/product/vision.md` and `context/product/concepts.md`.
- Do not add a feature that is not in `context/product/master-feature-list.md`.
- Do not start a feature PRD unless a human names the feature and the questions that block it are answered in `context/product/open-questions.md`.
- Do not answer those questions yourself.
- Do not write code unless the feature status is `plan-approved` or `implementing`.
- Do not plan or code in the session that just wrote the spec.
- Do not open a production deploy. Hosting is undecided.
- Do not merge `feature/<slug>` to `main`. That merge is a human action (ADR-0009).
- Do not delete ADRs or edit vendored skills.

## Done

`bin/ci` from the repository root is green, the feature status matches the artifact you wrote, and your final message says which prompt in `context/workflow/prompts.md` should run next.
