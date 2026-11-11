# Run a feature through agents

Read `context/workflow/operating-model.md` once. The diagrams are in `context/workflow/flows.md`. Use a new session for interview, spec, design, and plan. After plan approval, paste Run once.

1. Interview. You answer one question at a time. Confirm `intent.md`.
2. Spec. You read `spec.md` and send it back, or hold approval until any screens exist.
3. Design, when the spec has a screen. You accept the screenshots or send them back. Status stays `spec-draft` until you approve the spec.
4. Plan. You approve the task list when it has more than one task.
5. Paste the Run prompt once. The implementer merges each task pull request into the feature branch.
6. When it stops with no tasks left, you merge the feature branch to `main` and set `done`.

Deploy is a separate request, after an ADR names a host. Do not ask the coding agent to ship.

If a session starts coding while status is still `spec-draft`, stop it. The status in the feature README is the board.
