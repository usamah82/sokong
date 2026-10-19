# Run a feature through agents

Read `context/workflow/operating-model.md` once. Then use a new session per phase and the matching block in `context/workflow/prompts.md`.

1. Interview. You answer one question at a time. Confirm `intent.md`.
2. Spec. You approve `spec.md` or send it back. Nobody codes first.
3. Plan. You approve the task list when it has more than one task.
4. Implement. The agent checks off one task, runs `bin/ci`, and opens a pull request.
5. Review in a session that was not the implementer. Give it the spec path and the diff.
6. You merge.

Deploy is a separate request, after an ADR names a host. Do not ask the coding agent to ship.

If a session starts coding while status is still `spec-draft`, stop it. The status in the feature README is the board.
