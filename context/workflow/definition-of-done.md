# Definition of done

The standing checklist is `.cursor/references/definition-of-done.md`. Acceptance criteria stay on the task. Both have to be true.

For this repo, "tests pass" and "lint passes" mean `bin/ci` from the repository root exits 0. That command runs setup, RuboCop, bundler-audit, Brakeman, and `bin/rails test` inside `backend/`.

Also required here:

- The feature README links the spec the change implements, or the commit names the ADR or existing spec for a fix that is not a new feature.
- A new or changed HTTP contract is described in that feature's `spec.md`.
- An expensive-to-reverse choice has a new ADR. Old ADRs stay.
- `config/master.key` and `storage/` are not in the commit.

Observability beyond the `/up` check is not required until a feature has a production path. Say so in the pull request instead of pretending metrics exist.
