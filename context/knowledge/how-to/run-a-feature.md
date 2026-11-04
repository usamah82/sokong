# Run a feature through agents

Read `context/workflow/operating-model.md` once. Then use a new session per phase and the matching block in `context/workflow/prompts.md`.

1. Interview. You answer one question at a time. Confirm `intent.md`.
2. Spec. You read `spec.md` and send it back, or hold approval until any screens exist.
3. Design, when the spec has a screen. You accept the screenshots or send them back. Status stays `spec-draft` until you approve the spec.
4. Plan. You approve the task list, including when one task remains. Set status to `plan-approved`.
5. For each hop, paste `Continue the build loop` from `prompts.md` into a new chat. The session does one of implement, review, or fix, writes `handoff.md`, and stops.
6. On `spec-stop`, you change the spec or tasks, or you say how the loop should continue.
7. The ready hop merges the pull request and sets status to `done`. You do not merge it.

If a hop dies after `Claim: taken`, paste the recovery line from that same prompt into a new chat. A checkpoint in `tasks.md` is a review hop, not a pause for you.

Deploy is a separate request, after an ADR names a host. Do not ask the coding agent to ship.

If a session starts coding while status is still `spec-draft`, stop it. The status in the feature README is the board.
